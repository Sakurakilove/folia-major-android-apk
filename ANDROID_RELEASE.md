# Folia Android

基于 [chthollyphile/folia-major](https://github.com/chthollyphile/folia-major) v0.7.20 的 Android 移植。许可证沿用 GNU AGPL v3，见 LICENSE。

当前版本：**0.7.20-mobile.16**，ARM64，最低 Android 8，目标 SDK 37。

[APK 下载](https://github.com/Sakurakilove/folia-major-android-apk/releases/download/v0.7.20-mobile.16/Folia-v0.7.20-mobile.16-arm64.apk) · [发布记录与源码包](https://github.com/Sakurakilove/folia-major-android-apk/releases/tag/v0.7.20-mobile.16)

用户已确认启动、音频、返回及滑动/缩放不闪；mobile.15 仍有拖动卡顿、不跟手和恢复提示重复。本版将提示确认改为独立持久回执，Android 单指移动不再额外排一帧，裁剪在硬保护之前并发准备；时间线手机卡片改为自然行高。按指定 AndroidLiquidGlass 仓库移植原生 AGSL 核心，启用折射、深度法线、七色色散与方向高光；原生 RenderEffect 读取同一 WebView 单次输出，没有截图或再次 View.draw。玻璃内部文字/交互保持 DOM，光学作用于边缘，支持 Android 13+。手机效果与功耗仍待确认。

**当前限制：**采用 Kyant shader 核心的源码级原生集成，未使用其 Compose 双背景录制；光学处理限定边缘，材质中部仍由网页绘制。Android 8–12 无 RuntimeShader，保留材质回退；未宣称已验证手机 GPU 性能或功耗。Discord 暂不接入。

后续工作与审查结论见 [WORKLOG.md](WORKLOG.md)，开发约束见 [AGENTS.md](AGENTS.md)。Android 构建与适配源码见 android/、src/platform/android/ 与 packaging/android/。
