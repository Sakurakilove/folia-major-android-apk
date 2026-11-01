#pragma once
#include "analysis_frame.h"
#include <array>
#include <atomic>
#include <cstring>

namespace folia {
// Atomic payload words avoid C++ data races; failed reads never alter the caller's last complete frame.
class AnalysisSnapshot {
public:
    void publish(const AnalysisFrame& frame) {
        guard_.fetch_add(1, std::memory_order_acq_rel);
        std::atomic_thread_fence(std::memory_order_release);
        const auto* source = reinterpret_cast<const uint8_t*>(&frame);
        for (size_t i = 0; i < words_.size(); ++i) {
            uint64_t word;
            std::memcpy(&word, source + i * sizeof(word), sizeof(word));
            words_[i].store(word, std::memory_order_relaxed);
        }
        guard_.fetch_add(1, std::memory_order_release);
    }
    bool read(AnalysisFrame& target) const {
        std::array<uint64_t, sizeof(AnalysisFrame) / sizeof(uint64_t)> copy{};
        for (int attempt = 0; attempt < 2; ++attempt) {
            const uint64_t before = guard_.load(std::memory_order_acquire);
            if (before == 0 || (before & 1)) continue;
            for (size_t i = 0; i < words_.size(); ++i) copy[i] = words_[i].load(std::memory_order_relaxed);
            // Acquire fence keeps payload reads ahead of the final generation check on ARM64.
            std::atomic_thread_fence(std::memory_order_acquire);
            if (before == guard_.load(std::memory_order_acquire)) {
                std::memcpy(static_cast<void*>(&target), copy.data(), sizeof(target));
                return true;
            }
        }
        return false;
    }
private:
    static_assert(std::atomic<uint64_t>::is_always_lock_free);
    std::atomic<uint64_t> guard_{0};
    std::array<std::atomic<uint64_t>, sizeof(AnalysisFrame) / sizeof(uint64_t)> words_{};
};
}
