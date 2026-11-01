#include "fft_kernel.h"
#include <algorithm>
#include <cmath>

namespace folia {
namespace {
constexpr double pi = 3.1415926535897932384626433832795;
double energy(const AnalysisFrame& frame, double low, double high) {
    const double hz_per_bin = static_cast<double>(frame.sample_rate) / kFftSize;
    const int start = std::clamp(static_cast<int>(std::floor(low / hz_per_bin)), 0, static_cast<int>(kSpectrumBins - 1));
    const int end = std::clamp(static_cast<int>(std::floor(high / hz_per_bin)), start, static_cast<int>(kSpectrumBins - 1));
    double sum = 0;
    for (int i = start; i <= end; ++i) sum += frame.spectrum[i];
    return sum / (end - start + 1);
}
double process(double value, double exponent) { return std::pow(value / 255.0, exponent) * 255.0; }
}

FftKernel::FftKernel() {
    for (size_t i = 0; i < kFftSize; ++i) {
        const double angle = 2 * pi * i / kFftSize;
        window_[i] = .42 - .5 * std::cos(angle) + .08 * std::cos(2 * angle);
        uint16_t source = i, reverse = 0;
        for (int bit = 0; bit < 11; ++bit) { reverse = (reverse << 1) | (source & 1); source >>= 1; }
        reversed_[i] = reverse;
    }
    for (size_t i = 0; i < kSpectrumBins; ++i) twiddles_[i] = std::polar(1.0, -2 * pi * i / kFftSize);
}

void FftKernel::clear_smoothing() { smoothed_.fill(0); }

void FftKernel::analyze(const std::array<float, kFftSize>& samples, uint32_t rate, AnalysisFrame& out) {
    for (size_t i = 0; i < kFftSize; ++i) work_[reversed_[i]] = samples[i] * window_[i];
    for (size_t length = 2; length <= kFftSize; length <<= 1) {
        const size_t half = length / 2, step = kFftSize / length;
        for (size_t base = 0; base < kFftSize; base += length) {
            for (size_t i = 0; i < half; ++i) {
                const auto even = work_[base + i], odd = work_[base + i + half] * twiddles_[i * step];
                work_[base + i] = even + odd;
                work_[base + i + half] = even - odd;
            }
        }
    }
    out.sample_rate = rate;
    for (size_t i = 0; i < kSpectrumBins; ++i) {
        const double magnitude = std::abs(work_[i]) / kFftSize;
        smoothed_[i] = .6 * smoothed_[i] + .4 * magnitude;
        const double db = 20 * std::log10(std::max(smoothed_[i], 1e-30));
        out.spectrum[i] = static_cast<uint8_t>(std::clamp(std::floor(255.0 * (db + 100) / 70), 0.0, 255.0));
    }
    const double bass = energy(out, 20, 150), low_mid = energy(out, 150, 400);
    out.power = process((bass + low_mid) / 2, 3);
    out.bands[0] = process(bass, 1.8);
    out.bands[1] = process(low_mid, 2);
    out.bands[2] = process(energy(out, 400, 1200), 2);
    out.bands[3] = process(energy(out, 1000, 3500), 1.5);
    out.bands[4] = process(energy(out, 3500, 12000), 2);
}
}
