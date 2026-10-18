# Folia Android APK

Android 构建基于 [chthollyphile/folia-major](https://github.com/chthollyphile/folia-major)，上游 v0.7.20。

请在本仓库 **Releases** 页面下载 ARM64 APK，可覆盖安装之前的 mobile 版本。

## 0.7.20-mobile.5

- 原生 AndroidLiquidGlass 播放条，保留歌名、歌手、播放 / 暂停、切歌和自定义功能按钮。
- 按播放条实际位置避让资料库导航、字幕及工具面板；弹窗出现时原生层退让。
- 透明状态栏，内容延伸到状态栏下，操作按钮保留安全距离。
- 延续手机缩放与渲染优化；compile / target SDK 37。

仅做编译、签名及安装包静态校验，实机效果和功耗仍待验证。

液态玻璃库：[Kyant0/AndroidLiquidGlass](https://github.com/Kyant0/AndroidLiquidGlass)，Maven `io.github.kyant0:backdrop:2.0.1`。
