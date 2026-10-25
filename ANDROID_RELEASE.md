# Folia Android

基于 [chthollyphile/folia-major](https://github.com/chthollyphile/folia-major) v0.7.20 的 Android 移植。许可证沿用 GNU AGPL v3，见 LICENSE。

当前版本：**0.7.20-mobile.12**，ARM64，最低 Android 8，目标 SDK 37。

[APK 下载](https://github.com/Sakurakilove/folia-major-android-apk/releases/download/v0.7.20-mobile.12/Folia-v0.7.20-mobile.12-arm64.apk) · [发布记录与源码包](https://github.com/Sakurakilove/folia-major-android-apk/releases/tag/v0.7.20-mobile.12)

用户已确认音频、捏合和返回通过。本版仅修正滑动裁剪时的图块呈现顺序，避免对保留封面节点反复 detach/reinsert；动画和交互实现保留，滑动效果仍待手机实测。详细实施状态见 `docs/android/REPAIR_STATUS.md`。

**当前限制：**暂时关闭 Kyant 原生折射层，控制栏使用网页实时背景模糊。必要检查与实际交付记录见 WORKLOG.md；尚未在用户手机上确认闪烁与功耗改善。Discord 暂不接入。

后续工作与审查结论见 [WORKLOG.md](WORKLOG.md)，开发约束见 [AGENTS.md](AGENTS.md)。Android 构建与适配源码见 android/、src/platform/android/ 与 packaging/android/。
