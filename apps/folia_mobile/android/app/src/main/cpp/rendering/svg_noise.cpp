/*
 * SVG fractal-noise table/sampling port from Skia (Copyright 2013 Google Inc.).
 * BSD-3-Clause; pinned sources and license: lib/rendering/noise/UPSTREAM.md.
 */
#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <new>
#include <vector>

namespace {
// Normalized, permuted uint16 gradients retain the original SVG seed stream.
struct Noise {
    std::array<std::uint8_t, 256> permutation{};
    std::array<std::array<std::array<std::uint16_t, 2>, 256>, 4> gradients{};
    Noise() {
        int seed = 1;
        auto random = [&seed]() {
            int next = 16807 * (seed % 127773) - 2836 * (seed / 127773);
            if (next <= 0) next += 2147483647;
            return seed = next;
        };
        for (auto& channel : gradients) {
            for (int i = 0; i < 256; ++i) {
                permutation[i] = static_cast<std::uint8_t>(i);
                channel[i][0] = random() % 512;
                channel[i][1] = random() % 512;
            }
        }
        for (int i = 255; i > 0; --i) {
            std::swap(permutation[i], permutation[random() % 256]);
        }
        const auto source = gradients;
        for (int c = 0; c < 4; ++c) {
            for (int i = 0; i < 256; ++i) {
                const auto& from = source[c][permutation[i]];
                float x = (static_cast<int>(from[0]) - 256) / 256.0f;
                float y = (static_cast<int>(from[1]) - 256) / 256.0f;
                const double magnitude = std::sqrt(static_cast<double>(x) * x + static_cast<double>(y) * y);
                if (magnitude > 0) {
                    x = static_cast<float>(x / magnitude);
                    y = static_cast<float>(y / magnitude);
                }
                gradients[c][i][0] = static_cast<std::uint16_t>(std::floor((x + 1) * 32767.5f + .5f));
                gradients[c][i][1] = static_cast<std::uint16_t>(std::floor((y + 1) * 32767.5f + .5f));
            }
        }
    }
    static float stitchedFrequency(float frequency, float extent) {
        if (frequency == 0) return 0;
        const float low = std::floor(extent * frequency) / extent;
        const float high = std::ceil(extent * frequency) / extent;
        return frequency / low < high / frequency ? low : high;
    }
    std::array<float, 4> sample(float x, float y, float frequency, int stitch) const {
        std::array<float, 4> color{};
        float nx = (x + .5f) * frequency, ny = (y + .5f) * frequency, ratio = 1;
        auto dot = [&](int c, int i, float px, float py) {
            const auto& v = gradients[c][i & 255];
            const float vx = v[0] * (2.0f / 65535.0f) - 1;
            const float vy = v[1] * (2.0f / 65535.0f) - 1;
            return vx * px + vy * py;
        };
        auto lerp = [](float from, float to, float p) { return from + (to - from) * p; };
        for (int octave = 0; octave < 2; ++octave) {
            const float fx = std::floor(nx), fy = std::floor(ny), dx = nx - fx, dy = ny - fy;
            int x0 = static_cast<int>(fx), y0 = static_cast<int>(fy), x1 = x0 + 1, y1 = y0 + 1;
            if (x0 >= stitch) x0 -= stitch;
            if (x1 >= stitch) x1 -= stitch;
            if (y0 >= stitch) y0 -= stitch;
            if (y1 >= stitch) y1 -= stitch;
            const int p0 = permutation[x0 & 255], p1 = permutation[x1 & 255];
            const float sx = dx * dx * (3 - 2 * dx), sy = dy * dy * (3 - 2 * dy);
            for (int c = 0; c < 4; ++c) {
                const float a = lerp(dot(c, p0 + y0, dx, dy), dot(c, p1 + y0, dx - 1, dy), sx);
                const float b = lerp(dot(c, p0 + y1, dx, dy - 1), dot(c, p1 + y1, dx - 1, dy - 1), sx);
                color[c] += lerp(a, b, sy) * ratio;
            }
            nx *= 2; ny *= 2; stitch *= 2; ratio *= .5f;
        }
        for (float& channel : color) channel = std::clamp(channel * .5f + .5f, 0.0f, 1.0f);
        return color;
    }
};
struct Texture {
    int width, height;
    std::vector<std::uint8_t> bytes;
};
std::uint8_t byte(float value) {
    return static_cast<std::uint8_t>(std::floor(std::clamp(value, 0.0f, 1.0f) * 255 + .5f));
}
}

extern "C" {
std::uint32_t folia_noise_abi_version() { return 1; }
// Raw linear-light SVG noise. The engine applies the original SVG color matrix,
// linear-to-sRGB filter and rect opacity after this 8-bit intermediate.
void* folia_noise_create(int kind, double css_extent, double dpr) {
    if (kind < 0 || kind > 2 || !std::isfinite(dpr) || dpr <= 0 || !std::isfinite(css_extent) || css_extent <= 0) return nullptr;
    const int logical = kind == 1 ? 160 : 180;
    const double extent = std::ceil(css_extent * dpr);
    if (extent < 1 || extent > 8192) return nullptr; // Reject; never silently lower resolution.
    try {
        static const Noise noise;
        auto result = new Texture();
        try {
            result->width = result->height = static_cast<int>(extent);
            result->bytes.resize(static_cast<std::size_t>(result->width) * result->height * 4);
            const float frequency = Noise::stitchedFrequency(kind == 0 ? .92f : kind == 1 ? .9f : .85f, static_cast<float>(logical * 1.2));
            const int stitch = static_cast<int>(std::floor(static_cast<float>(logical * 1.2) * frequency + .5f));
            for (int y = 0; y < result->height; ++y) {
                for (int x = 0; x < result->width; ++x) {
                    const auto color = noise.sample(static_cast<float>((x + .5) / dpr * logical / css_extent), static_cast<float>((y + .5) / dpr * logical / css_extent), frequency, stitch);
                    const auto index = (static_cast<std::size_t>(y) * result->width + x) * 4;
                    for (int c = 0; c < 3; ++c) result->bytes[index + c] = byte(color[c] * color[3]);
                    result->bytes[index + 3] = byte(color[3]);
                }
            }
            return result;
        } catch (...) { delete result; return nullptr; }
    } catch (...) { return nullptr; }
}
int folia_noise_width(void* p) { return p ? static_cast<Texture*>(p)->width : 0; }
int folia_noise_height(void* p) { return p ? static_cast<Texture*>(p)->height : 0; }
const std::uint8_t* folia_noise_pixels(void* p) { return p ? static_cast<Texture*>(p)->bytes.data() : nullptr; }
std::size_t folia_noise_size(void* p) { return p ? static_cast<Texture*>(p)->bytes.size() : 0; }
void folia_noise_close(void* p) { delete static_cast<Texture*>(p); }
}
