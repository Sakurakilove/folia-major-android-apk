# Flutter / Kotlin 全量重写

**交付硬性门槛以根目录 AGENTS.md 为准：包括前端在内的全部代码必须完成重写，功能、界面、交互及动画保持原样；全量迁移完成后检查全部差异并修复，确认一致才可交付。不得以继续保留旧前端宣称全量完成，也不得发布另做的精简界面代替等价迁移。**

分支：`feat/flutter-native-rewrite`。对照版本 mobile.17，基线提交 `45d7d8a27afc7efb7a33308824def68329a86651`。

选择 Flutter/Dart 管理界面、排版、手势与同一场景的动画；Kotlin 承载 Android 媒体、URI、密钥、权限与系统服务。目标是移除默认客户端中的 WebView/Node 常驻链路、逐帧桥传输和整屏玻璃重合成。选择框架不是已证实省电，手机瓦数必须另测。

## 功能兼容台账

| 领域 | 原实现入口 | 新实现/迁移状态 |
| --- | --- | --- |
| 启动、窗口、设置、国际化、主题 | bootstrap/App、stores、i18n | 新工程与壳开始；全设置/语言/迁移未完成 |
| 本地文件、音频、歌词入口 | localMusicService、FoliaDocumentIO | Kotlin SAF/Media3 + Dart 歌词为首条纵向链路 |
| 播放、队列、系统通知与时钟 | playback、FoliaPlaybackService | Kotlin 单输出 + 稀疏时钟锚；双 deck/全契约未完成 |
| 均衡器、全部音效、混音与分析 | audioEffects、automix | 原生 PCM/FFT/FFI 分析通路已实现；完整效果图、后效果取样、采样率等价与双 deck 未完成 |
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

## 已否决的 alpha.1 架构实验（不是迁移候选）

用户已明确否决该包：自建 Material 界面、Flutter 图标和空本地库不符合原版。发布页已标为撤回迁移候选；保留原始资产与历史，仅供内部架构研究。以下内容仅记录当时实验范围，不构成可继续发布预览的许可。

已实现代码路径：真实本地 SAF 导入/直接 URI 音频、原生 Media3 队列与自动下一首/后台播放、原生媒体会话、独立 URI 库持久化、单调时钟锚点、原生拖动/缩放墙、LRC/YRC 基础对象、莫奈 envelope/spring/十粒子、全 DPR glyph/glow mask 缓存和局部七色色散 shader。库可静止无 ticker；不可见时原生取消时钟发送。页面/播放图标保留可运行的淡变/缩放路径，完整转场/肖像/副字幕/主题变体仍待移植。

尚未移植的动画、背景、在线平台、全音效/FFT/automix、模组和数据迁移不算完成；因此本包只能验证新架构、不能与完整旧版的功耗直接对标。需要同输入、同背景/音效/动画工作量完成后再作有效 A/B。

构建说明见工程 README。必要检查为 analyzer、原 TS 值生成的最小 Dart 数学/歌词时间检查、ARM64 release 编译与签名。未做模拟器/截图，也没有实机功耗或完整像素兼容结论。

已撤回候选的历史记录：[native-v0.1.0-alpha.1](https://github.com/Sakurakilove/folia-major-android-apk/releases/tag/native-v0.1.0-alpha.1)。源代码/源码包提交 `e935dc77bd4fab0d2c47915a5156981d1a47f845`；后续规则和源码修订不改变该历史二进制。

## 按原实现迁移中的规则与资源

- 原始 `LyricData/Line/Word` 元数据（音节、ruby、合唱、副声部、分词覆盖、TTML agents 等）由 `lib/lyrics/lyric_types.dart` 与 `lyric_document.dart` 保留，包含未知字段往返；原来的两个基础导入解析器尚不等价于原版全解析链路。
- `render_hints.dart`、`grapheme_timing.dart`、`subtitle_tracks.dart`、`monet_lyrics_model.dart`、`monet_rail_layout.dart`、`word_coloring.dart`、`font_stacks.dart`、共享 `folia_typography.dart` 和 `monet_portrait_layers.dart` 按原函数迁移；最小差分脚本从原 TS 执行生成数据核对，不把固定合成文字度量当成字体/画面相同的证据。
- 原生封面组件先解码再叠层，保留 900ms 淡变、快速切歌的四层上限、失败保留旧封面和动画封面播放。原生字形缓存新增字体回退、字重/变量轴、locale、行高与字体加载代次键；原生测量适配器与最终 DOM 排版的严格差异仍须检查、修复。
- `assets/original` 从原源文件导出四套语言、默认主题/设置和 2,118 个 Lucide 图标节点，携带来源摘要与许可证；原生按需解析图标 Path，有界缓存，不使用 Material 图标替代。资源相同不等于最终界面已相同。
- 上述组件仍在接入完整页面，不能把存在独立规则模块写成完整页面/全量迁移已完成；不交付新的替换 APK。


## 当前内容组件与公共运行时（未达到交付条件）

- `lib/monet/page/monet_poster_scene.dart` 组合原版海报布局、元数据/标题、歌词栏/字幕、胶囊、频谱及立绘编辑/漂移/交接，保留各自时序。原 Chromium 三个视口的数值仅作 CSS 参考；字体排版、像素、手势和整页动画尚未通过 Android 对照。
- `lib/still` 独立迁移原三行静态样式；不把其他模式换成 Monet。其间隙留行、直接翻译字段、日夜混合与文字投影仍须在完整宿主上核对。
- `lib/visualizer/transitions` 复用原层状态、softFocus、首帧等待和背景 underNext；48 组原状态函数对照通过，完整切换与宿主整合未验收。`scene_frame_clock.dart` 按真实监听者调度全刷新率 tick，保留离屏时间，不在静态模式强开帧循环；尚待完整 root 接入。
- 原生 `analysis` 模块仅在可见消费者请求时运行 FFT，停用时无周期线程唤醒；播放线程保留有界 PCM 历史以供即时恢复。FFI 一致性快照 ABI 为版本 1 / 1112 字节；不通过 channel 逐帧传递音频数组。仍需完整后效果、重采样及设备播放头的等价验证。
- `AudioTrack` / `LibraryStore` 保留未知嵌套源字段，新增专辑/原生标签通路。实验 URI 目录并不等价于原版全部 SongResult/LocalSong、旧数据库或账号迁移。
- 实验 root 仍不是原版完整界面。78 组清单当前 9 组进行中，0 组取得最终等价验证；其余保留待办。没有发布新的替换 APK，也没有实机功耗降幅结论。

- Classic 的稳定随机布局、原设置边界和整行呼吸组件，以及 Classic/Partita 共用的逐词时序/布局/正文 motion 规划已移植；24 组原 useMemo 布局（含负时间）、3 类 render-hint profile 和 18 组词状态参数对照通过。实际 Glyph/glow/ripple 渲染、全文布局、字幕组件、共享宿主和交互仍待接入，不能据此记两个样式完成。
- 语义/粘连布局保留原词、不重写歌词文档，读取保存/自动/原生分词的优先级与 UTF-16 偏移保持原规则。32 组布局与 32 组共享字幕内容选择对照已纳入原规则检查；plain ICU 分词在检查中由原函数提供，原生 ICU/jieba/BudouX 引擎仍待迁移，不用字素拆分冒充语义分词。

- 公共物理弹簧已按原锁定 motion-dom 13.4.2 的计算/速度/停止规则移植并接入歌词栏；150 个原库采样通过，许可证随资源保留。duration/bounce、默认缓动、WAAPI 轨迹取样、首帧/打断时序及实机画面仍未通过完整核对。

- 共享 `visualizer/subtitles/visualizer_subtitle_overlay.dart` 内容/动画/光晕/跟随组件已加入；一个 headless 生命周期检查验证退场保留、底部信号直接跟随与 ticker 清理。完整宿主接入、外观和精确动画对照仍未完成。
- `rendering/css_text.dart` / `css_case.dart` 保留 CSS 空白和 full uppercase 显示规则，Unicode 数据由 `tool/export_css_case.cjs` 生成，记录工具链版本和来源，附官方 Unicode 许可证；不改变存储的歌曲/主题数据。最终浏览器文字变换/字体兼容仍是交付门槛的一部分。

- duration/bounce/visualDuration 派生 spring 及物理参数优先级已迁移，108 个原库选项采样通过；property/default-transition 完整适配和 WAAPI 取样未完成，仍无全部动画等价结论。

- JS/WAAPI 分流按原库支持表和各组件直接 Element.animate 的实际分支迁移；numeric keyframes、命名 easing、逐段曲线/时间数组已有原库对照（209 个采样）。Classic 呼吸/立绘漂移/挂钩脉冲已接入，原生立绘的中断 900ms 淡变与退休/解码租约也有最小生命周期回归。完整宿主、WAAPI spring 曲线取样、逐帧时序、颜色/复杂 CSS 插值和最终像素仍未完成核对。

- Shared GlowWord 现有实际正文/光晕/副歌 ripple 绘制和行级帧生命周期；原 54 组 glow 参数/30 个 Motion 颜色采样通过，Classic atomic flex 与行内容 presenter 已加入。两个小型 headless 检查覆盖 native 字体颜色/重叠覆盖及暂停/离屏/5s 旋转清理；完整宿主、热更新/量化切换、原浏览器像素与实机功耗仍未验收。为保留 native glyph coverage，已撤掉本轮不等价的纹理着色实验，正文复用已排版 paragraph，光晕保留全 DPR 输入。

- Partita 的原布局/分块/字号/引导线/逐词内容已加入，108 组原参数对照通过；63 个原 follower 操作/帧采样与字幕 direct-baseline/spring-presence 检查通过。完整 scene/热更新/像素仍未验收。
- 原生 ICU 批量通路已 Kotlin 增量编译，Dart codec/缓存最小检查通过；原 jieba/HMM/BudouX 数据与纯 Dart 算法已加入，50 混合流程/24 参考文本/40 加词权重通过，仍缺设备 ICU 兼容与后台 isolate/文档 rebake 接线。用户将主页封面墙列为当前优先项，下一批优先推进原 wall/Bravais 迁移，不缩减其他既定范围。

### 持续迁移：封面墙卡片与原生封面（2026-11-01）

Bravais 卡片 flip/wave/entrance 的有限动画、固定 Ada WHATWG URL 适配和 Kotlin/FFI 描述符封面读取已加入；动图流直接更新 retained RenderImage，内联图片本地 FFI 解码。保留原图像尺寸规则与动图帧序，后台 HTTP 缓存遵守响应缓存策略。当前 HTTP/content 新加载和取消仍用稀疏 channel 元数据；完整卡片与所有主页/数据/root 未接入，不能由模块检查推出整页等价或功耗下降。必要检查和未完成项详见根 WORKLOG 的 WALL-NATIVE-04 / ARTWORK-NATIVE-01..03。当前 10 组进行中、0 组最终验证，继续全量迁移，不发布简化 APK。

### 持续迁移：真实卡片内容与样式目标（2026-11-07）

原 Bravais compact/heading/expanded 内容、徽标、管理隐藏与队列/链接/菜单动作已加入实际 native 组件；控件 reveal 和快速 hover 反向使用有限 native 绘制轨迹。新增 source selector 样式目标、渐变/scrim/内外阴影组件。整卡图层及艺术封面、整页数据/入口仍未组装，标题 native 断行、字体、阴影及色彩空间尚未严格比较，不能称主页或前端已完成。详见 WORKLOG WALL-NATIVE-05..07 / TEXT-WALL-01；不发布简化界面，不缩小全部 14 样式/6 背景/3 资料库的范围。

### 持续迁移：原艺术封面与 CSS 色彩路径（2026-11-07）

已加入原 artist 的实际取色/状态回退/双层混色组件和有限 native shader/时钟，保留完整动图与显示分辨率；日/夜原 CSS 对照区分 legacy sRGB 与 ICC/D50 Oklab。专辑原切点、拼贴位置、碎片种子与坐标序列化对照通过。拼贴已改双纹理合成后统一滤镜；mosaic/shard、整卡有限 CSS 材质与实际卡片内容已有组件装配。原 CORS/auth 可读性路由、墙页交互/数据/缝/root、加载呼吸/文字与阴影细节及最终手机外观/功耗仍未完成。详见 WORKLOG WALL-ART-01..06 / WALL-SKIN-01；源码检查点后继续，不视为交付物。

### 持续迁移：探索形状、显示与 retained 墙体（2026-11-07）

探索页原 lot/heading/周期/最近副本/让位和 display/透光/finite/删除投影已加入；双半 BravaisWallView 现可组装完整卡片，实际小范围宿主检查通过，camera 更新不重建卡片。全部 seam/入口/导航/记忆/keyboard/list/海报/封面飞行、原生 scene/root、其余页面/样式/背景/平台与最终像素/功耗验收仍未完成。参见 WORKLOG WALL-SHAPE-01 / WALL-DISPLAY-01 / WALL-HOST-03；这些组件不是可交付整页。


### 持续迁移：墙体宿主、缝动画与海报材质（2026-11-07）

实际 BravaisWallScene 已组装 camera/cull/plate/reflow/card 和隐藏场景时钟域；seam 等级、宽度目标与开合/倾斜/正文翻面已有 native 控制器。artist poster 卡片的10px内缩、外叠色、原 selector filter 优先级及卡片现代Oklab渐变接入实际绘制。修复最后一个有限动画注销时因延迟移除而留下的 parent tick；既有小例的静止/隐藏/恢复/卸载0监听与 analyzer 通过，不代表实机功耗或完整页面等价。缝真实布局/材质/全部正文、导航入口/原海报/封面飞行、全局字体/最终像素及其余全部迁移尚未完成。78组仍10进行中、68待迁移、0最终验证；原完整前端保持对照，继续工作，不发布阶段性APK。
