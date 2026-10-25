# Folia Android

基于 [chthollyphile/folia-major](https://github.com/chthollyphile/folia-major) v0.7.20 的 Android 移植。许可证沿用 GNU AGPL v3，见 LICENSE。

当前版本：**0.7.20-mobile.11**，ARM64，最低 Android 8，目标 SDK 37。

[APK 下载](https://github.com/Sakurakilove/folia-major-android-apk/releases/download/v0.7.20-mobile.11/Folia-v0.7.20-mobile.11-arm64.apk) · [发布记录与源码包](https://github.com/Sakurakilove/folia-major-android-apk/releases/tag/v0.7.20-mobile.11)

本版针对 mobile.10 用户确认音频通过、三类闪烁未改善的反馈，分离墙面布局栅格与连续合成比例，并将页面级预见性返回变换移到 Android View；功能与动画实现保留，手机闪烁仍待实测。详细实施状态见 `docs/android/REPAIR_STATUS.md`。

**当前限制：**暂时关闭 Kyant 原生折射层，控制栏使用网页实时背景模糊。必要检查与实际交付记录见 WORKLOG.md；尚未在用户手机上确认闪烁与功耗改善。Discord 暂不接入。

后续工作与审查结论见 [WORKLOG.md](WORKLOG.md)，开发约束见 [AGENTS.md](AGENTS.md)。Android 构建与适配源码见 android/、src/platform/android/ 与 packaging/android/。
