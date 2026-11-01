#include "analysis_engine.h"
#include <jni.h>

// JNI is restricted to audio-sink capture and discrete lifecycle changes; Flutter reads frames through the C ABI.
extern "C" JNIEXPORT jboolean JNICALL
Java_top_izuna_foliamajor_next_analysis_NativeSpectrum_configureNative(JNIEnv*, jobject, jint rate, jint channels, jint encoding) {
    return folia::AnalysisEngine::shared().configure({static_cast<uint32_t>(rate), static_cast<uint32_t>(channels), static_cast<folia::PcmEncoding>(encoding)});
}
extern "C" JNIEXPORT void JNICALL
Java_top_izuna_foliamajor_next_analysis_NativeSpectrum_enabledNative(JNIEnv*, jobject, jboolean enabled) {
    folia::AnalysisEngine::shared().set_enabled(enabled);
}
extern "C" JNIEXPORT void JNICALL
Java_top_izuna_foliamajor_next_analysis_NativeSpectrum_resetNative(JNIEnv*, jobject) {
    folia::AnalysisEngine::shared().reset();
}
extern "C" JNIEXPORT void JNICALL
Java_top_izuna_foliamajor_next_analysis_NativeSpectrum_gainNative(JNIEnv*, jobject, jfloat gain) {
    folia::AnalysisEngine::shared().set_gain(gain);
}
extern "C" JNIEXPORT void JNICALL
Java_top_izuna_foliamajor_next_analysis_NativeSpectrum_invalidateClockNative(JNIEnv*, jobject) {
    folia::AnalysisEngine::shared().invalidate_clock();
}
extern "C" JNIEXPORT void JNICALL
Java_top_izuna_foliamajor_next_analysis_NativeSpectrum_offerNative(JNIEnv* env, jobject, jobject buffer,
    jint start, jint end, jlong pts_us, jfloat gain, jlong head_us, jlong head_ns, jfloat speed) {
    auto& engine = folia::AnalysisEngine::shared();
    const auto capacity = env->GetDirectBufferCapacity(buffer);
    if (start < 0 || end < start || end > capacity) return;
    const auto* bytes = static_cast<const uint8_t*>(env->GetDirectBufferAddress(buffer));
    if (!bytes) return;
    engine.offer(bytes + start, end - start, pts_us, gain, head_us, head_ns, speed);
}
