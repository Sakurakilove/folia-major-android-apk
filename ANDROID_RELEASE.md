# Folia Android

基于 [chthollyphile/folia-major](https://github.com/chthollyphile/folia-major) v0.7.20 的 Android 移植。许可证沿用 GNU AGPL v3，见 LICENSE。

当前版本：**0.7.20-mobile.7**，ARM64，最低 Android 8，目标 SDK 37。

[APK 下载](https://github.com/Sakurakilove/folia-major-android-apk/releases/download/v0.7.20-mobile.7/Folia-v0.7.20-mobile.7-arm64.apk) · [发布记录与源码包](https://github.com/Sakurakilove/folia-major-android-apk/releases/tag/v0.7.20-mobile.7)

此版移除 mobile.6 的重复硬件 WebView 绘制路径，并修复拖动合帧、捏合取消和视口高度变化重置缩放的问题。

**当前限制：**暂时关闭 Kyant 原生折射层，控制栏使用网页实时背景模糊。编译、签名及 11 项相关单测通过；尚未在用户手机上确认闪烁与功耗改善。Discord 暂不接入。

后续工作与审查结论见 [WORKLOG.md](WORKLOG.md)，开发约束见 [AGENTS.md](AGENTS.md)。Android 构建与适配源码见 android/、src/platform/android/ 与 packaging/android/。
