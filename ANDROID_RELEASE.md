# Folia Android

基于 [chthollyphile/folia-major](https://github.com/chthollyphile/folia-major) v0.7.20 的 Android 移植。许可证沿用 GNU AGPL v3，见 LICENSE。

当前版本：**0.7.20-mobile.17**，ARM64，最低 Android 8，目标 SDK 37。

[APK 下载](https://github.com/Sakurakilove/folia-major-android-apk/releases/download/v0.7.20-mobile.17/Folia-v0.7.20-mobile.17-arm64.apk) · [发布记录与源码包](https://github.com/Sakurakilove/folia-major-android-apk/releases/tag/v0.7.20-mobile.17)

用户已确认启动、音频、返回及滑动/缩放不闪；mobile.16 在骁龙 8 Gen 2 上仍有约 10W 功耗反馈。本版缩小玻璃属性观察范围，Java 预计算光学几何并加 AGSL 无效区域快路径；合并莫奈词时钟、移交粒子原生合成器、缓存频谱窗口/复用点池。保留原扫字/发光/折射/七色色散、粒子轨迹和全分辨率，不降低用户帧率。新增有界原生计数日志帮助区分整机电池读数和宿主 CPU；实际节电幅度待实机验证。

**当前限制：**采用 Kyant shader 核心的源码级原生集成，未使用其 Compose 双背景录制；光学处理限定边缘，材质中部仍由网页绘制。Android 8–12 无 RuntimeShader，保留材质回退；未宣称已验证手机 GPU 性能或功耗。Discord 暂不接入。

后续工作与审查结论见 [WORKLOG.md](WORKLOG.md)，开发约束见 [AGENTS.md](AGENTS.md)。Android 构建与适配源码见 android/、src/platform/android/ 与 packaging/android/。

具体原生替换边界和剩余热点见 [POWER_REWRITE.md](docs/android/POWER_REWRITE.md)。
