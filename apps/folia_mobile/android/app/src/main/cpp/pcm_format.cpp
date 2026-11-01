#include "pcm_format.h"
#include <cmath>
#include <cstring>

namespace folia {
size_t PcmFormat::bytes_per_sample() const {
    switch (encoding) {
        case PcmEncoding::U8: return 1;
        case PcmEncoding::S16LE: case PcmEncoding::S16BE: return 2;
        case PcmEncoding::S24LE: case PcmEncoding::S24BE: return 3;
        case PcmEncoding::S32LE: case PcmEncoding::S32BE: case PcmEncoding::F32LE: case PcmEncoding::F32BE: return 4;
        case PcmEncoding::F64LE: case PcmEncoding::F64BE: return 8;
        default: return 0;
    }
}
bool PcmFormat::valid() const { return rate > 0 && rate <= 768000 && channels > 0 && channels <= 32 && bytes_per_sample() != 0; }

namespace {
uint64_t bits(const uint8_t* p, size_t bytes, bool big) {
    uint64_t result = 0;
    for (size_t i = 0; i < bytes; ++i) result |= static_cast<uint64_t>(p[i]) << ((big ? bytes - 1 - i : i) * 8);
    return result;
}
float value(const uint8_t* p, PcmEncoding encoding) {
    switch (encoding) {
        case PcmEncoding::U8: return (static_cast<int>(p[0]) - 128) / 128.0f;
        case PcmEncoding::S16LE: case PcmEncoding::S16BE:
            return static_cast<int16_t>(bits(p, 2, encoding == PcmEncoding::S16BE)) / 32768.0f;
        case PcmEncoding::S24LE: case PcmEncoding::S24BE: {
            uint32_t raw = bits(p, 3, encoding == PcmEncoding::S24BE);
            if (raw & 0x800000) raw |= 0xff000000;
            return static_cast<int32_t>(raw) / 8388608.0f;
        }
        case PcmEncoding::S32LE: case PcmEncoding::S32BE:
            return static_cast<float>(static_cast<int32_t>(bits(p, 4, encoding == PcmEncoding::S32BE)) / 2147483648.0);
        case PcmEncoding::F32LE: case PcmEncoding::F32BE: {
            const uint32_t raw = bits(p, 4, encoding == PcmEncoding::F32BE);
            float result; std::memcpy(&result, &raw, sizeof(result)); return result;
        }
        case PcmEncoding::F64LE: case PcmEncoding::F64BE: {
            const uint64_t raw = bits(p, 8, encoding == PcmEncoding::F64BE);
            double result; std::memcpy(&result, &raw, sizeof(result)); return static_cast<float>(result);
        }
        default: return 0;
    }
}
}

float PcmFormat::mono(const uint8_t* frame, float gain) const {
    const auto sample = [&](size_t channel) { return value(frame + channel * bytes_per_sample(), encoding); };
    float result;
    // Web Audio speaker-layout downmix, rather than an arbitrary average that includes the LFE channel.
    switch (channels) {
        case 2: result = .5f * (sample(0) + sample(1)); break;
        case 4: result = .25f * (sample(0) + sample(1) + sample(2) + sample(3)); break;
        case 6: result = .7071067811865476f * (sample(0) + sample(1)) + sample(2) + .5f * (sample(4) + sample(5)); break;
        default: result = sample(0); break;
    }
    result *= gain;
    return std::isfinite(result) ? result : 0;
}
}
