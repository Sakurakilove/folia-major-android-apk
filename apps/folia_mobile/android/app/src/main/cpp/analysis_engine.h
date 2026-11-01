#pragma once
#include "analysis_snapshot.h"
#include "fft_kernel.h"
#include "pcm_timeline.h"
#include "playback_anchor.h"
#include <thread>

namespace folia {
// The worker sleeps on eventfd without a timer; only visible-frame demand asks for another FFT.
class AnalysisEngine {
public:
    static AnalysisEngine& shared();
    AnalysisEngine();
    ~AnalysisEngine();
    bool configure(PcmFormat format);
    void reset();
    void invalidate_clock() { anchor_.invalidate(); }
    void set_enabled(bool enabled);
    void set_gain(float gain) { gain_.store(gain, std::memory_order_relaxed); }
    bool enabled() const { return enabled_.load(std::memory_order_acquire); }
    void offer(const uint8_t* bytes, size_t size, int64_t pts_us, float gain,
               int64_t head_us, int64_t head_ns, float speed);
    int read(AnalysisFrame& frame);
private:
    void notify();
    void run();
    int event_ = -1;
    std::thread worker_;
    std::atomic<bool> enabled_{false}, quit_{false};
    std::atomic<uint64_t> lease_{0};
    std::atomic<float> gain_{1};
    PcmTimeline pcm_;
    PlaybackAnchor anchor_;
    FftKernel fft_;
    AnalysisSnapshot snapshot_;
};
int64_t monotonic_ns();
}
