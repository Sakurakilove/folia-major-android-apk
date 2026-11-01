#include "../android/app/src/main/cpp/analysis_engine.h"
#include <array>

// Host-only fixture entrypoints; this file is never part of the Android CMake target.
extern "C" void folia_fixture_begin() {
    static std::array<int16_t, 8192> samples{};
    samples.fill(8192);
    auto& engine = folia::AnalysisEngine::shared();
    engine.configure({48000, 1, folia::PcmEncoding::S16LE});
    engine.set_enabled(true);
    engine.offer(reinterpret_cast<const uint8_t*>(samples.data()), samples.size() * sizeof(int16_t),
                 0, 1, 100000, folia::monotonic_ns(), 1);
}
extern "C" void folia_fixture_stop() { folia::AnalysisEngine::shared().set_enabled(false); }
