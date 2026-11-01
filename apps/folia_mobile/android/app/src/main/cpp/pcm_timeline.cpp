#include "pcm_timeline.h"
#include <algorithm>
#include <cstring>

namespace folia {
bool PcmTimeline::configure(PcmFormat format) {
    if (format.rate != format_.rate || format.channels != format_.channels || format.encoding != format_.encoding) reset();
    format_ = format;
    return format_.valid();
}
void PcmTimeline::reset() {
    first_frame_.store(write_frame_, std::memory_order_relaxed);
    generation_.fetch_add(1, std::memory_order_release);
}
void PcmTimeline::append(const uint8_t* bytes, size_t byte_count, int64_t presentation_us, float gain) {
    if (!format_.valid()) return;
    const size_t stride = format_.bytes_per_sample() * format_.channels, total = byte_count / stride;
    const uint64_t generation = generation_.load(std::memory_order_acquire);
    for (size_t offset = 0; offset < total;) {
        const size_t count = std::min(chunk_, total - offset);
        reserved_end_.store(write_frame_ + count, std::memory_order_relaxed);
        std::atomic_thread_fence(std::memory_order_release);
        const uint64_t first = write_frame_;
        for (size_t i = 0; i < count; ++i) {
            const float sample = format_.mono(bytes + (offset + i) * stride, gain);
            uint32_t raw; std::memcpy(&raw, &sample, sizeof(raw));
            samples_[(write_frame_++) & (capacity_ - 1)].store(raw, std::memory_order_relaxed);
        }
        const uint64_t ticket = ++next_block_;
        auto& block = blocks_[ticket & (block_capacity_ - 1)];
        block.ticket.store(0, std::memory_order_relaxed);
        std::atomic_thread_fence(std::memory_order_release);
        block.generation.store(generation, std::memory_order_relaxed);
        block.first_frame.store(first, std::memory_order_relaxed);
        block.presentation_us.store(presentation_us + static_cast<int64_t>(offset * 1000000ULL / format_.rate), std::memory_order_relaxed);
        block.count.store(count, std::memory_order_relaxed);
        block.rate.store(format_.rate, std::memory_order_relaxed);
        block.ticket.store(ticket, std::memory_order_release);
        published_block_.store(ticket, std::memory_order_release);
        offset += count;
    }
}

bool PcmTimeline::window(int64_t time, std::array<float, kFftSize>& output, uint32_t& rate, uint64_t& end_frame) const {
    const uint64_t generation = generation_.load(std::memory_order_acquire);
    const uint64_t latest = published_block_.load(std::memory_order_acquire);
    const uint64_t oldest = latest > block_capacity_ ? latest - block_capacity_ + 1 : 1;
    const uint64_t epoch_first = first_frame_.load(std::memory_order_acquire);
    for (uint64_t ticket = latest; ticket >= oldest && ticket > 0; --ticket) {
        const auto& block = blocks_[ticket & (block_capacity_ - 1)];
        if (block.ticket.load(std::memory_order_acquire) != ticket) continue;
        const uint64_t block_generation = block.generation.load(std::memory_order_relaxed);
        const uint64_t first = block.first_frame.load(std::memory_order_relaxed);
        const int64_t pts = block.presentation_us.load(std::memory_order_relaxed);
        const uint32_t count = block.count.load(std::memory_order_relaxed), sample_rate = block.rate.load(std::memory_order_relaxed);
        std::atomic_thread_fence(std::memory_order_acquire);
        if (block.ticket.load(std::memory_order_acquire) != ticket || block_generation != generation || !sample_rate || time < pts) continue;
        const uint64_t offset = std::min<uint64_t>(count, static_cast<uint64_t>(time - pts) * sample_rate / 1000000ULL);
        const uint64_t end = first + offset;
        if (end < epoch_first) return false;
        const uint64_t begin = end >= kFftSize ? end - kFftSize : 0;
        for (size_t i = 0; i < kFftSize; ++i) {
            if (end < kFftSize - i || end - (kFftSize - i) < epoch_first) { output[i] = 0; continue; }
            const uint64_t source = end - (kFftSize - i);
            const uint32_t raw = samples_[source & (capacity_ - 1)].load(std::memory_order_relaxed);
            std::memcpy(&output[i], &raw, sizeof(raw));
        }
        std::atomic_thread_fence(std::memory_order_acquire);
        const uint64_t reserved = reserved_end_.load(std::memory_order_acquire);
        if (generation != generation_.load(std::memory_order_acquire) || reserved > begin + capacity_) return false;
        rate = sample_rate; end_frame = end;
        return true;
    }
    return false;
}
}
