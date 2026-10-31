# Folia Android

基于 [chthollyphile/folia-major](https://github.com/chthollyphile/folia-major) v0.7.20 的 Android 移植。许可证沿用 GNU AGPL v3，见 LICENSE。

当前版本：**0.7.20-mobile.13**，ARM64，最低 Android 8，目标 SDK 37。

[APK 下载](https://github.com/Sakurakilove/folia-major-android-apk/releases/download/v0.7.20-mobile.13/Folia-v0.7.20-mobile.13-arm64.apk) · [发布记录与源码包](https://github.com/Sakurakilove/folia-major-android-apk/releases/tag/v0.7.20-mobile.13)

用户已确认音频、捏合和返回通过。本版修正覆盖安装时旧运行时与失败半成品的清理流程，降低解压空间峰值，并保留启动失败的具体阶段和异常类型；不重置用户账户或设置。沿用 mobile.12 的稳定图块顺序，启动与滑动效果仍待手机实测。详细实施状态见 `docs/android/REPAIR_STATUS.md`。

**当前限制：**暂时关闭 Kyant 原生折射层，控制栏使用网页实时背景模糊。必要检查与实际交付记录见 WORKLOG.md；尚未在用户手机上确认闪烁与功耗改善。Discord 暂不接入。

后续工作与审查结论见 [WORKLOG.md](WORKLOG.md)，开发约束见 [AGENTS.md](AGENTS.md)。Android 构建与适配源码见 android/、src/platform/android/ 与 packaging/android/。
