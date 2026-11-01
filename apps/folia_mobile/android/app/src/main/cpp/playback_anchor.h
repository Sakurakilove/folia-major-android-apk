#pragma once
#include <atomic>
#include <cstdint>
#include <cstring>
#include <limits>

namespace folia {
// AudioSink's presentation clock, in the same timestamp domain as its PCM buffers; no UI/decoder-ahead guess.
class PlaybackAnchor {
public:
    void set(int64_t pts_us, int64_t sampled_ns, float speed) {
        if (pts_us == std::numeric_limits<int64_t>::min()) return;
        guard_.fetch_add(1, std::memory_order_acq_rel);
        std::atomic_thread_fence(std::memory_order_release);
        pts_.store(pts_us, std::memory_order_relaxed);
        at_.store(sampled_ns, std::memory_order_relaxed);
        uint32_t raw; std::memcpy(&raw, &speed, sizeof(raw));
        speed_.store(raw, std::memory_order_relaxed);
        valid_.store(true, std::memory_order_relaxed);
        guard_.fetch_add(1, std::memory_order_release);
    }
    uint64_t revision() const { return guard_.load(std::memory_order_acquire); }
    void invalidate() {
        guard_.fetch_add(1, std::memory_order_acq_rel);
        std::atomic_thread_fence(std::memory_order_release);
        valid_.store(false, std::memory_order_relaxed);
        guard_.fetch_add(1, std::memory_order_release);
    }
    bool time(int64_t now_ns, uint64_t after_revision, int64_t& result) const {
        for (int attempt = 0; attempt < 2; ++attempt) {
            const uint64_t guard = guard_.load(std::memory_order_acquire);
            if (guard <= after_revision || (guard & 1)) continue;
            const int64_t pts = pts_.load(std::memory_order_relaxed), at = at_.load(std::memory_order_relaxed);
            const uint32_t raw = speed_.load(std::memory_order_relaxed);
            const bool valid = valid_.load(std::memory_order_relaxed);
            std::atomic_thread_fence(std::memory_order_acquire);
            if (guard != guard_.load(std::memory_order_acquire)) continue;
            if (!valid) return false;
            float speed; std::memcpy(&speed, &raw, sizeof(speed));
            result = pts + static_cast<int64_t>((now_ns > at ? now_ns - at : 0) / 1000.0 * speed);
            return true;
        }
        return false;
    }
private:
    std::atomic<uint64_t> guard_{0};
    std::atomic<int64_t> pts_{0}, at_{0};
    std::atomic<uint32_t> speed_{0};
    std::atomic<bool> valid_{false};
};
}
