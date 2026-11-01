#include "analysis_engine.h"
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <poll.h>
#include <sys/eventfd.h>
#include <time.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/resource.h>

namespace folia {
int64_t monotonic_ns() { timespec now{}; clock_gettime(CLOCK_MONOTONIC, &now); return now.tv_sec * 1000000000LL + now.tv_nsec; }
AnalysisEngine& AnalysisEngine::shared() { static AnalysisEngine engine; return engine; }
AnalysisEngine::AnalysisEngine() {
    event_ = eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK);
    if (event_ >= 0) {
        try { worker_ = std::thread([this] { run(); }); }
        catch (...) { close(event_); event_ = -1; }
    }
}
AnalysisEngine::~AnalysisEngine() { quit_.store(true, std::memory_order_release); notify(); if (worker_.joinable()) worker_.join(); if (event_ >= 0) close(event_); }
bool AnalysisEngine::configure(PcmFormat format) {
    const uint64_t generation = pcm_.generation();
    const bool supported = pcm_.configure(format);
    if (generation != pcm_.generation()) anchor_.invalidate();
    return supported && event_ >= 0;
}
void AnalysisEngine::reset() { pcm_.reset(); anchor_.invalidate(); }
void AnalysisEngine::notify() {
    if (event_ < 0) return;
    const uint64_t one = 1;
    // Nonblocking: the UI/audio threads never wait for FFT, and accumulated wakeups collapse into one request.
    ssize_t result;
    do { result = write(event_, &one, sizeof(one)); } while (result < 0 && errno == EINTR);
}
void AnalysisEngine::set_enabled(bool wanted) {
    if (wanted == enabled_.load(std::memory_order_acquire)) return;
    lease_.fetch_add(1, std::memory_order_acq_rel);
    enabled_.store(wanted && event_ >= 0, std::memory_order_release);
    notify();
}
void AnalysisEngine::offer(const uint8_t* bytes, size_t size, int64_t pts_us, float gain,
                           int64_t head_us, int64_t head_ns, float speed) {
    // Retain only the bounded PCM history during playback so resuming a scene does not wait for queued audio to catch up.
    // This runs on the already active audio thread; disabled scenes still schedule no FFT or extra worker wakeups.
    anchor_.set(head_us, head_ns, speed);
    set_gain(gain);
    if (bytes && size) pcm_.append(bytes, size, pts_us, 1);
}
int AnalysisEngine::read(AnalysisFrame& frame) {
    if (!enabled()) return 0;
    notify();
    AnalysisFrame next;
    if (!snapshot_.read(next) || next.generation != pcm_.generation()) return 0;
    frame = next;
    return 1;
}
void AnalysisEngine::run() {
    pthread_setname_np(pthread_self(), "FoliaFFT");
    setpriority(PRIO_PROCESS, 0, 5);
    std::array<float, kFftSize> samples{};
    uint64_t last_end = UINT64_MAX, last_generation = 0, sequence = 0;
    uint32_t previous_rate = 0;
    pollfd descriptor{event_, POLLIN, 0};
    while (!quit_.load(std::memory_order_acquire)) {
        if (poll(&descriptor, 1, -1) < 0) { if (errno == EINTR) continue; break; }
        uint64_t requests;
        while (::read(event_, &requests, sizeof(requests)) < 0 && errno == EINTR) {}
        if (quit_.load(std::memory_order_acquire) || !enabled()) continue;
        const uint64_t lease = lease_.load(std::memory_order_acquire), generation = pcm_.generation();
        const int64_t now = monotonic_ns();
        int64_t target_us;
        if (!anchor_.time(now, 0, target_us)) continue;
        uint32_t rate; uint64_t end;
        if (!pcm_.window(target_us, samples, rate, end) || (last_end == end && last_generation == generation)) continue;
        if (rate != previous_rate) { fft_.clear_smoothing(); previous_rate = rate; }
        const float gain = gain_.load(std::memory_order_relaxed);
        if (gain != 1) for (auto& sample : samples) sample *= gain;
        AnalysisFrame next;
        fft_.analyze(samples, rate, next);
        if (!enabled() || lease != lease_.load(std::memory_order_acquire) || generation != pcm_.generation()) continue;
        next.sequence = ++sequence; next.generation = generation; next.sampled_at_ns = now;
        snapshot_.publish(next);
        last_end = end; last_generation = generation;
    }
}
}

extern "C" uint32_t folia_spectrum_abi_version() { return folia::kAnalysisAbi; }
extern "C" uint32_t folia_spectrum_frame_size() { return sizeof(folia::AnalysisFrame); }
extern "C" void* folia_spectrum_allocate_frame() { return std::calloc(1, sizeof(folia::AnalysisFrame)); }
extern "C" void folia_spectrum_free_frame(void* frame) { std::free(frame); }
extern "C" int32_t folia_spectrum_read(void* frame, uint32_t bytes) {
    if (!frame || bytes != sizeof(folia::AnalysisFrame)) return -1;
    folia::AnalysisFrame copy;
    const int result = folia::AnalysisEngine::shared().read(copy);
    if (result == 1) std::memcpy(frame, &copy, sizeof(copy));
    return result;
}
