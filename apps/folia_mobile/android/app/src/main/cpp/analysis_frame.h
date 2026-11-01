#pragma once
#include <cstddef>
#include <cstdint>
#include <type_traits>

// Versioned, fixed-size snapshot shared with Dart FFI; no heap payloads or platform-channel serialization.
namespace folia {
constexpr uint32_t kAnalysisAbi = 1;
constexpr size_t kFftSize = 2048;
constexpr size_t kSpectrumBins = kFftSize / 2;
struct alignas(8) AnalysisFrame {
    uint32_t abi = kAnalysisAbi;
    uint32_t bytes = sizeof(AnalysisFrame);
    uint64_t sequence = 0;
    uint64_t generation = 0;
    int64_t sampled_at_ns = 0;
    uint32_t sample_rate = 0;
    uint32_t bin_count = kSpectrumBins;
    double power = 0;
    double bands[5] = {};
    uint8_t spectrum[kSpectrumBins] = {};
};
static_assert(sizeof(AnalysisFrame) == 1112);
static_assert(std::is_trivially_copyable<AnalysisFrame>::value);
static_assert(offsetof(AnalysisFrame, spectrum) == 88);
}

extern "C" {
uint32_t folia_spectrum_abi_version();
uint32_t folia_spectrum_frame_size();
void* folia_spectrum_allocate_frame();
void folia_spectrum_free_frame(void* frame);
int32_t folia_spectrum_read(void* frame, uint32_t bytes);
}
