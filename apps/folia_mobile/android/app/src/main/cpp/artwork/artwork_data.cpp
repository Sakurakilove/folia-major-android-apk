#include "artwork_fd.h"
#include <cstdlib>
#include <new>
#include <string_view>
#include <vector>

// WHATWG-normalized data URLs decode straight into native bytes. Inline images never become a serialized platform message or a temporary disk file.
namespace {
struct Data { std::vector<std::uint8_t> bytes; };
bool space(unsigned char c) { return c == 9 || c == 10 || c == 12 || c == 13 || c == 32; }
int hex(unsigned char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return -1;
}
int sextet(unsigned char c) {
    if (c >= 'A' && c <= 'Z') return c - 'A';
    if (c >= 'a' && c <= 'z') return c - 'a' + 26;
    if (c >= '0' && c <= '9') return c - '0' + 52;
    if (c == '+') return 62;
    if (c == '/') return 63;
    return -1;
}
bool base64_metadata(std::string_view meta) {
    while (!meta.empty() && space(static_cast<unsigned char>(meta.back()))) meta.remove_suffix(1);
    const auto semi = meta.rfind(';');
    if (semi == std::string_view::npos) return false;
    auto suffix = meta.substr(semi + 1);
    while (!suffix.empty() && suffix.front() == ' ') suffix.remove_prefix(1);
    if (suffix.size() != 6) return false;
    constexpr std::string_view flag = "base64";
    for (std::size_t i = 0; i < flag.size(); ++i) {
        auto c = static_cast<unsigned char>(suffix[i]);
        if (c >= 'A' && c <= 'Z') c += 'a' - 'A';
        if (c != static_cast<unsigned char>(flag[i])) return false;
    }
    return true;
}
bool decode(std::string_view input, Data& result) {
    if (input.substr(0, 5) != "data:") return false;
    input = input.substr(0, input.find('#'));
    const auto comma = input.find(',');
    if (comma == std::string_view::npos) return false;
    const bool base64 = base64_metadata(input.substr(5, comma - 5));
    const auto body = input.substr(comma + 1);
    result.bytes.reserve(base64 ? body.size() / 4 * 3 : body.size());
    std::uint32_t accumulator = 0;
    unsigned bits = 0, padding = 0;
    std::size_t count = 0;
    for (std::size_t i = 0; i < body.size(); ++i) {
        auto c = static_cast<unsigned char>(body[i]);
        if (c == '%' && i + 2 < body.size()) {
            const auto a = hex(static_cast<unsigned char>(body[i + 1]));
            const auto b = hex(static_cast<unsigned char>(body[i + 2]));
            if (a >= 0 && b >= 0) { c = static_cast<unsigned char>(a * 16 + b); i += 2; }
        }
        if (!base64) { result.bytes.push_back(c); continue; }
        if (space(c)) continue;
        if (c == '=') { if (++padding > 2) return false; continue; }
        const int value = sextet(c);
        if (value < 0 || padding) return false;
        ++count; accumulator = (accumulator << 6) | static_cast<std::uint32_t>(value); bits += 6;
        if (bits >= 8) { bits -= 8; result.bytes.push_back(static_cast<std::uint8_t>((accumulator >> bits) & 255)); }
    }
    if (base64 && (count % 4 == 1 || (padding && ((count + padding) % 4 != 0)))) return false;
    return true;
}
}
extern "C" {
void* folia_artwork_allocate(std::size_t bytes) { return std::malloc(bytes); }
void folia_artwork_release(void* bytes) { std::free(bytes); }
void* folia_artwork_decode_data(const std::uint8_t* bytes, std::size_t length) {
    auto* data = new (std::nothrow) Data();
    if (!data) return nullptr;
    try {
        if (decode(std::string_view(reinterpret_cast<const char*>(bytes), length), *data)) return data;
    } catch (...) { /* Caller receives a normal failed artwork decode, not an exception across FFI. */ }
    delete data; return nullptr;
}
const std::uint8_t* folia_artwork_data_bytes(void* data) { return data ? static_cast<Data*>(data)->bytes.data() : nullptr; }
std::size_t folia_artwork_data_size(void* data) { return data ? static_cast<Data*>(data)->bytes.size() : 0; }
void folia_artwork_close_data(void* data) { delete static_cast<Data*>(data); }
}
