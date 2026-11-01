#pragma once
#include "analysis_frame.h"
#include "pcm_format.h"
#include <array>
#include <atomic>

namespace folia {
// One producer, one analysis consumer; 262144 samples retain buffered-ahead PCM for presentation-time selection.
class PcmTimeline {
public:
    bool configure(PcmFormat format);
    void reset();
    void append(const uint8_t* bytes, size_t byte_count, int64_t presentation_us, float gain);
    bool window(int64_t presentation_us, std::array<float, kFftSize>& samples, uint32_t& rate, uint64_t& end_frame) const;
    uint64_t generation() const { return generation_.load(std::memory_order_acquire); }
private:
    static constexpr size_t capacity_ = 262144, block_capacity_ = 2048, chunk_ = 256;
    struct Block {
        std::atomic<uint64_t> ticket{0}, generation{0}, first_frame{0};
        std::atomic<int64_t> presentation_us{0};
        std::atomic<uint32_t> count{0}, rate{0};
    };
    PcmFormat format_;
    uint64_t write_frame_ = 0, next_block_ = 0;
    std::atomic<uint64_t> generation_{1}, first_frame_{0}, reserved_end_{0}, published_block_{0};
    std::array<std::atomic<uint32_t>, capacity_> samples_{};
    std::array<Block, block_capacity_> blocks_{};
};
}
