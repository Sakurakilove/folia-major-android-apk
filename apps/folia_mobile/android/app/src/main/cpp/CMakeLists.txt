cmake_minimum_required(VERSION 3.22)
project(folia_analysis LANGUAGES CXX)

# No audio output or format conversion is installed by this passive, bounded analysis module.
add_library(folia_analysis SHARED
    analysis_engine.cpp analysis_jni.cpp fft_kernel.cpp pcm_format.cpp pcm_timeline.cpp)
target_compile_features(folia_analysis PRIVATE cxx_std_17)
target_compile_options(folia_analysis PRIVATE -Wall -Wextra -Werror -O3)
target_link_options(folia_analysis PRIVATE -Wl,-z,max-page-size=16384)
