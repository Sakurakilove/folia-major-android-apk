#pragma once
#include "analysis_frame.h"
#include <array>
#include <complex>

namespace folia {
// The original analyser uses a 2048-point Blackman FFT, smoothing .6 and default -100/-30 dB bounds.
class FftKernel {
public:
    FftKernel();
    void analyze(const std::array<float, kFftSize>& samples, uint32_t rate, AnalysisFrame& out);
    void clear_smoothing();
private:
    std::array<double, kFftSize> window_{};
    std::array<uint16_t, kFftSize> reversed_{};
    std::array<std::complex<double>, kSpectrumBins> twiddles_{};
    std::array<std::complex<double>, kFftSize> work_{};
    std::array<double, kSpectrumBins> smoothed_{};
};
}
