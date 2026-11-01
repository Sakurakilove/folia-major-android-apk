#pragma once
#include <cstddef>
#include <cstdint>

namespace folia {
// Read-only analysis formats; the original ByteBuffer and audio samples are never changed.
enum class PcmEncoding : int32_t { Invalid, U8, S16LE, S16BE, S24LE, S24BE, S32LE, S32BE, F32LE, F32BE, F64LE, F64BE };
struct PcmFormat {
    uint32_t rate = 0, channels = 0;
    PcmEncoding encoding = PcmEncoding::Invalid;
    size_t bytes_per_sample() const;
    bool valid() const;
    float mono(const uint8_t* frame, float gain) const;
};
}
