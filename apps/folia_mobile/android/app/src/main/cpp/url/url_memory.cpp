#include <cstddef>
#include <cstdint>
#include <cstdlib>
#ifdef __ANDROID__
#include <jni.h>
#include <limits>
#include <string>
extern "C" {
#include "../vendor/ada_url/ada_c.h"
}
#endif

// Shared-library-local allocation avoids assuming a platform libc soname in Dart; URL/parameter owners retain the upstream Ada free functions.
extern "C" {
std::uint32_t folia_url_abi_version() { return 1; }
void* folia_url_allocate(std::size_t bytes) { return std::malloc(bytes); }
void folia_url_release(void* value) { std::free(value); }
}

#ifdef __ANDROID__
extern "C" JNIEXPORT jbyteArray JNICALL
Java_top_izuna_foliamajor_next_artwork_NativeArtworkUrls_resolveUtf8(JNIEnv* env, jobject, jbyteArray base, jbyteArray value) {
    if (!base || !value) return nullptr;
    try {
    const auto base_size = env->GetArrayLength(base), size = env->GetArrayLength(value);
    std::string base_text(static_cast<std::size_t>(base_size), '\0'), text(static_cast<std::size_t>(size), '\0');
    env->GetByteArrayRegion(base, 0, base_size, reinterpret_cast<jbyte*>(base_text.data()));
    env->GetByteArrayRegion(value, 0, size, reinterpret_cast<jbyte*>(text.data()));
    if (env->ExceptionCheck()) return nullptr;
    auto url = ada_parse_with_base(text.c_str(), text.size(), base_text.c_str(), base_text.size());
    if (!url) return nullptr;
    if (!ada_is_valid(url)) { ada_free(url); return nullptr; }
    const auto href = ada_get_href(url);
    jbyteArray result = nullptr;
    if (href.length <= static_cast<std::size_t>(std::numeric_limits<jsize>::max())) {
        result = env->NewByteArray(static_cast<jsize>(href.length));
        if (result) env->SetByteArrayRegion(result, 0, static_cast<jsize>(href.length), reinterpret_cast<const jbyte*>(href.data));
    }
    ada_free(url); return result;
    } catch (...) { return nullptr; }
}
#endif
