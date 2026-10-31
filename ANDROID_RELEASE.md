# Folia Android

基于 [chthollyphile/folia-major](https://github.com/chthollyphile/folia-major) v0.7.20 的 Android 移植。许可证沿用 GNU AGPL v3，见 LICENSE。

当前版本：**0.7.20-mobile.15**，ARM64，最低 Android 8，目标 SDK 37。

[APK 下载](https://github.com/Sakurakilove/folia-major-android-apk/releases/download/v0.7.20-mobile.15/Folia-v0.7.20-mobile.15-arm64.apk) · [发布记录与源码包](https://github.com/Sakurakilove/folia-major-android-apk/releases/tag/v0.7.20-mobile.15)

用户已确认音频、返回、启动、滑动/缩放不闪。本版统一播放条、设置窗、播放器面板与墙工具的实时背景玻璃材质，移除 Android 右上灯泡入口，右下面板入口避让播放条；恢复手机控件微动效与布局 spring。设置入场先等待原生帧，再播放原动画。前端复用裁剪几何/歌词索引，Node 改异步文件读取，Android 文档 IO 改为后台有界按序执行。手机设置闪帧、滑动流畅度与实际功耗仍待实测。详细状态见 `docs/android/REPAIR_STATUS.md`。

**当前限制：**暂时关闭 Kyant 原生折射层，控制栏使用网页实时背景模糊。必要检查与实际交付记录见 WORKLOG.md；尚未在用户手机上确认闪烁与功耗改善。Discord 暂不接入。

后续工作与审查结论见 [WORKLOG.md](WORKLOG.md)，开发约束见 [AGENTS.md](AGENTS.md)。Android 构建与适配源码见 android/、src/platform/android/ 与 packaging/android/。
