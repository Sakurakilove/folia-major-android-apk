# Flutter / Kotlin 全量重写

分支：`feat/flutter-native-rewrite`。对照版本 mobile.17，基线提交 `45d7d8a27afc7efb7a33308824def68329a86651`。

选择 Flutter/Dart 管理界面、排版、手势与同一场景的动画；Kotlin 承载 Android 媒体、URI、密钥、权限与系统服务。目标是移除默认客户端中的 WebView/Node 常驻链路、逐帧桥传输和整屏玻璃重合成。选择框架不是已证实省电，手机瓦数必须另测。

## 功能兼容台账

| 领域 | 原实现入口 | 新实现/迁移状态 |
| --- | --- | --- |
| 启动、窗口、设置、国际化、主题 | bootstrap/App、stores、i18n | 新工程与壳开始；全设置/语言/迁移未完成 |
| 本地文件、音频、歌词入口 | localMusicService、FoliaDocumentIO | Kotlin SAF/Media3 + Dart 歌词为首条纵向链路 |
| 播放、队列、系统通知与时钟 | playback、FoliaPlaybackService | Kotlin 单输出 + 稀疏时钟锚；双 deck/全契约未完成 |
| 均衡器、全部音效、混音与分析 | audioEffects、automix | 未迁移；不能以原生播放器默认输出冒充全音效 |
| 莫奈文字、扫字、glow、粒子、肖像 | visualizer/monet | 首个动画迁移目标；需字体/像素/交互实机对照 |
| 其他歌词样式与模式切换 | visualizer registry/各 entry | 全部保留在迁移清单，尚未移植 |
| 通用/莫奈/漫游/隐现/星空/网页背景 | backgrounds registry | 各 shader/暂停/过渡逐项移植，尚未完整覆盖 |
| 三类资料库、墙、倾斜与翻牌 | library/suites、wall、lattice | 原生 Flutter 场景与手势开始；行为兼容待完成 |
| 玻璃、设置/队列/播放条遮挡 | androidGlass、Kyant AGSL | 局部 Flutter Backdrop + shader 迁移，不截图、不整 WebView 录制 |
| 在线平台与登录 | onlineMusic/omni、providerRegistry | 网易云/QQ/酷狗/波点/YTM/Spotify/Navidrome 全部待迁移，保留原路由和鉴权契约 |
| 缓存、数据库、同步、备份、密钥 | db、stores、sync、native keys | 原数据/密钥不触动；兼容迁移未完成 |
| AI 配色、分词、歌词检索/编辑/导出 | services、analysis、lyricExport | 未迁移 |
| Folium 模组与自定义 HTML/CSS/JS | mods | 兼容难点：Dart 不能直接执行 DOM/CSS 模组。需要按需隔离兼容宿主或正式等价原生 API；未解决前不能宣称完整兼容，也不删除模组功能 |
| 无障碍/图标/键盘与触摸语义 | 原 DOM 语义、Lucide、输入命令 | 首包仅基础控件语义；画布语义/完整 Lucide 与输入等价尚未完成 |
| OBS、遥控、桌面歌词、导出、壁纸 | obs、remote、window、wallpaper | 未迁移 |

旧代码作为对照保留；新工程在 `apps/folia_mobile`，使用独立安装 ID。没有把缺失项隐藏成“精简版完成”。完整客户端的替换条件是上表的功能、数据和动画都通过相应门槛。

## 渲染与功耗约束

- 单一 Flutter scene；没有背景 WebView/Node，也没有把实时玻璃换成截图。
- 连续动画只使 painter/局部 layer 重绘；轨迹/扫字/glow 使用原绝对时间函数，保留用户刷新率和全 DPR。
- 字形/两个 glow 层在字体/布局变化时生成，逐帧只改 shader uniform；缓存有上限且释放原图。
- 玻璃只在有限表面创建 backdrop/filter 输入，保留七色色散、法线和高光；不再给整棵 WebView 挂效果。
- Kotlin 原生音频/前台服务拥有唯一音频输出和焦点，Dart 只收离散状态/时钟锚。完整 EQ/音效/自动混音必须另行等价移植。
- 同一设备固定亮度、刷新设置、歌曲、动画和操作比较 GPU/CPU/温度及整机电池读数；未取得实机证据不报瓦数降幅。

## 首个迁移预览 alpha.1

已实现代码路径：真实本地 SAF 导入/直接 URI 音频、原生 Media3 队列与自动下一首/后台播放、原生媒体会话、独立 URI 库持久化、单调时钟锚点、原生拖动/缩放墙、LRC/YRC 基础对象、莫奈 envelope/spring/十粒子、全 DPR glyph/glow mask 缓存和局部七色色散 shader。库可静止无 ticker；不可见时原生取消时钟发送。页面/播放图标保留可运行的淡变/缩放路径，完整转场/肖像/副字幕/主题变体仍待移植。

尚未移植的动画、背景、在线平台、全音效/FFT/automix、模组和数据迁移不算完成；因此本包只能验证新架构、不能与完整旧版的功耗直接对标。需要同输入、同背景/音效/动画工作量完成后再作有效 A/B。

构建说明见工程 README。必要检查为 analyzer、原 TS 值生成的最小 Dart 数学/歌词时间检查、ARM64 release 编译与签名。未做模拟器/截图，也没有实机功耗或完整像素兼容结论。

预览发布：[native-v0.1.0-alpha.1](https://github.com/Sakurakilove/folia-major-android-apk/releases/tag/native-v0.1.0-alpha.1)。源代码/源码包提交 `e935dc77bd4fab0d2c47915a5156981d1a47f845`；后续工作日志提交不改变该预览二进制。
