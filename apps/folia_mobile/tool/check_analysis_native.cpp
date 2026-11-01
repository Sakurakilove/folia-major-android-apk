#include "../android/app/src/main/cpp/analysis_engine.h"
#include <algorithm>
#include <cassert>
#include <chrono>
#include <cmath>
#include <cstring>
#include <iostream>
#include <memory>
#include <vector>

// Small native contract check: formats, presentation window, reset, FFT, coherent snapshots and demand lifecycle.
int main() {
    using namespace folia;
    const uint8_t half16[] = {0, 64}, half24[] = {0, 0, 64}, half32[] = {0, 0, 0, 64};
    assert((PcmFormat{48000, 1, PcmEncoding::S16LE}.mono(half16, 1) == .5f));
    assert((PcmFormat{48000, 1, PcmEncoding::S24LE}.mono(half24, 1) == .5f));
    assert((PcmFormat{48000, 1, PcmEncoding::S32LE}.mono(half32, 1) == .5f));
    float surround[] = {0, 0, 0, 1, 0, 0};
    assert((PcmFormat{48000, 6, PcmEncoding::F32LE}.mono(reinterpret_cast<uint8_t*>(surround), 1) == 0));
    PlaybackAnchor clock;
    int64_t position = -1;
    assert(!clock.time(2000000, 0, position));
    clock.set(100000, 1000000, 2);
    assert(clock.time(2000000, 0, position) && position == 102000);
    clock.invalidate();
    assert(!clock.time(3000000, 0, position));
    clock.set(300000, 4000000, 1);
    assert(clock.time(5000000, 0, position) && position == 301000);

    auto timeline = std::make_unique<PcmTimeline>();
    assert(timeline->configure({48000, 1, PcmEncoding::S16LE}));
    std::vector<int16_t> pcm(24000, 8192);
    std::fill(pcm.begin() + 12000, pcm.end(), -8192);
    timeline->append(reinterpret_cast<uint8_t*>(pcm.data()), pcm.size() * sizeof(int16_t), 0, 1);
    std::array<float, kFftSize> window{};
    uint32_t rate; uint64_t end;
    assert(timeline->window(100000, window, rate, end));
    assert(rate == 48000 && std::all_of(window.begin(), window.end(), [](float v) { return v == .25f; }));
    const auto generation = timeline->generation();
    timeline->reset();
    assert(timeline->generation() != generation && !timeline->window(100000, window, rate, end));
    timeline->append(reinterpret_cast<uint8_t*>(pcm.data()), 256 * sizeof(int16_t), 1000000, 1);
    assert(timeline->window(1006000, window, rate, end));
    assert(std::all_of(window.begin(), window.end() - 256, [](float v) { return v == 0; }));
    assert(std::all_of(window.end() - 256, window.end(), [](float v) { return v == .25f; }));

    FftKernel fft;
    for (size_t i = 0; i < window.size(); ++i) window[i] = .001 * std::sin(2 * 3.14159265358979323846 * 32 * i / kFftSize);
    AnalysisFrame frame;
    fft.analyze(window, 48000, frame);
    assert(std::max_element(std::begin(frame.spectrum), std::end(frame.spectrum)) - frame.spectrum == 32);
    assert(frame.spectrum[32] == 67 && frame.spectrum[31] == 50 && frame.spectrum[33] == 50);
    const auto first = frame.spectrum[32];
    fft.analyze(window, 48000, frame);
    assert(frame.spectrum[32] > first);

    AnalysisSnapshot snapshot;
    std::atomic<bool> done{false};
    std::thread writer([&] {
        for (uint64_t i = 1; i <= 500; ++i) {
            AnalysisFrame next; next.sequence = i; next.power = i;
            std::fill(std::begin(next.spectrum), std::end(next.spectrum), i % 255);
            snapshot.publish(next);
        }
        done.store(true);
    });
    do {
        if (snapshot.read(frame)) {
            assert(frame.power == frame.sequence);
            assert(std::all_of(std::begin(frame.spectrum), std::end(frame.spectrum), [&](uint8_t v) { return v == frame.sequence % 255; }));
        }
    } while (!done.load());
    writer.join();

    auto& engine = AnalysisEngine::shared();
    assert(engine.configure({48000, 1, PcmEncoding::S16LE}));
    // Capture the already queued PCM while no scene requests FFT; enabling must not wait for another decoded buffer.
    assert(!engine.enabled());
    engine.offer(reinterpret_cast<uint8_t*>(pcm.data()), pcm.size() * sizeof(int16_t), 0, 1, 100000, monotonic_ns(), 1);
    assert(engine.read(frame) == 0);
    engine.set_enabled(true);
    bool received = false;
    for (int attempt = 0; attempt < 200 && !received; ++attempt) {
        received = engine.read(frame) == 1;
        if (!received) std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    assert(received && frame.sample_rate == 48000 && frame.bin_count == 1024);
    engine.set_enabled(false);
    const auto sequence = frame.sequence;
    assert(engine.read(frame) == 0 && frame.sequence == sequence);
    void* allocation = folia_spectrum_allocate_frame();
    assert(allocation && folia_spectrum_frame_size() == 1112 && folia_spectrum_abi_version() == 1);
    assert(folia_spectrum_read(allocation, 1) == -1);
    folia_spectrum_free_frame(allocation);
    std::cout << "Native PCM/window/FFT/snapshot/lifecycle checks passed; full post-effects and visual parity remain unverified.\n";
}
