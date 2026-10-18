# Android 移植状态

## 原生液态玻璃与沉浸状态栏 0.7.20-mobile.5

- APK：https://litter.catbox.moe/5mzat1.apk（72 小时），ARM64，343967900 字节，versionCode 702005，同签名覆盖安装。

- 接入用户指定的 Kyant0/AndroidLiquidGlass（Maven `io.github.kyant0:backdrop:2.0.1`），以原生 Compose `drawBackdrop` / `vibrancy` / `blur` / `lens` 绘制播放条；不是 CSS 冒充。图标沿用现有 Lucide SVG，按钮继续调用原 React 操作，包括用户设置的两个功能槽位。
- 背景只截取播放条矩形，最大 540 像素宽；触控刷新至多每 200ms 一次，静止时只在歌曲、主题 / 几何变化后采样。原生进度每秒接收一次时钟，未新增全屏截图或后台采样循环。
- 用播放条实际矩形发布底部安全区，供资料库竖栏、聚焦卡、侧边面板、字幕和右下工具共享；右下弹出面板的高度预算也减掉避让区域。原生层检测到 DOM 弹窗遮盖时退让，使用原网页控件以保证弹窗层级和操作。
- 状态栏透明，页面背景延伸到状态栏下；移除原生内容的顶部 padding，返回按钮、提示按钮、竖栏和设置窗口单独使用刘海 / 状态栏安全距离；保留原生导航栏 / 键盘底部避让。
- 安卓 API 33 以下液态折射由库自身兼容回退。悬浮窗口、宽屏布局及原生层接入异常保留网页播放条。没有运行模拟器或做实机功耗验证。
- Kotlin、TypeScript 和 APK 构建 / 签名证据见 `validation/mobile5-release.json`。

## 紧凑播放条与手机绘制优化 0.7.20-mobile.4

- APK：https://litter.catbox.moe/ey4u8h.apk（72 小时），ARM64，340676250 字节，versionCode 702004，同签名覆盖安装。

- 用户反馈标题缺失、捏合闪烁、骁龙 8 Gen 2 整机约 8 W；这些是用户实机观察，并非本地基准。
- 手机播放条改为两行：歌名 / 歌手与上一首、播放 / 暂停、下一首同列，进度和两个自定义功能槽位在第二行。标题使用有实际宽度的布局，取消触屏悬停预览。手机播放条不使用桌面尺寸弹簧布局，减少高度跳变。
- 两根手指的连续事件合并成每显示帧一次相机写入，结束前提交最后坐标。关闭原生整页缩放，墙面仍支持自定义双指缩放。限制手机墙封面解码 DPR 为 1.5，避免高分辨率手机重复解码过大图片。
- 静止资料库即使播放音乐也降到 20 FPS，操作时恢复设定帧率，播放页面保留设定帧率。缩放 / 移动时延长交互提升；手机播放条与竖缝取消背景模糊，移除全屏 soft-light 噪点叠层。未降低音频质量，未移除歌词动画或功能槽位。
- 本地没有实机功耗、温度或捏合录屏数据，不承诺具体降温幅度。必要检查记录见 `validation/mobile4-release.json`；不运行 Android 模拟器。

## 启动 JSON 与系统栏修正版 0.7.20-mobile.3

- 最新截图显示原生 JSON 空输入错误，而非已挂载 React 的渲染失败。修正 ready.json 的“文件已存在但内容尚未完成”竞态：Node 写临时文件后原子重命名，原生端等待有效端口记录。截图本身不能证明错误一定发生于该读取点。
- 原生与本机 Node 的 RPC / 媒体协议连接显式绕过系统代理；空或无效 RPC 响应包含接口名及 HTTP 状态，避免失去错误上下文。没有对可能修改数据的 RPC 自动重试。
- 桥接初始化失败页使用明亮文字与本地化重试入口；原生恢复前后台后重设已保存的系统栏主题，避免 StatusBar 插件恢复默认样式覆盖图标颜色。
- 仅做就绪发布检查、前端构建、release Java 编译和签名校验，不做模拟器或实机测试。保留用户数据，版本号 702003，可覆盖安装。
- APK：https://litter.catbox.moe/2bela2.apk（72 小时），340675106 字节；证据 `validation/mobile3-release.json`。

## 启动与系统栏修正版 0.7.20-mobile.2

- 用户反馈 mobile.1 在启动标识消失后黑屏。此次撤销原生活动暂停通知对全局 RAF 的强制挂起；首屏挂载前不执行空闲限帧 / CSS 暂停，CSS 暂停只接受页面与原生同时不可见。此为风险逻辑修正，尚无用户设备日志证明唯一根因。
- 根渲染错误边界提供错误内容与重试入口，避免渲染异常留下空白。系统栏透明区由原生主题底色绘制，状态栏 / 导航栏图标按应用明暗主题设置，系统栏 / 刘海 / 键盘安全区由 MainActivity 统一处理。
- 仅运行针对手机首屏的 Chromium 检查与启动可见性回归（均通过），release Java 编译 / APK 签名通过；未做 Android 模拟器或实机测试。
- ARM64、versionCode 702002、沿用原签名，可覆盖旧版；证据 `validation/mobile2-release.json`。下载：https://litter.catbox.moe/vukiwu.apk（72 小时有效）。


## 手机适配构建 0.7.20-mobile.1

- 2026-10-18：按用户手机截图修改；保留竖排导航，取消单字缩写；播放条在手机上常驻展开，播放 / 暂停及切歌可直接操作；六个平台使用本地 logo；移除信息提示装饰图标。
- 新增双指拼贴缩放及原生网页缩放；设置窗口适配窄屏。前台默认 60 FPS，空闲 30 FPS，后台停绘；未更换歌词样式引擎。后端按需启动，媒体同步减少空闲唤醒，分析限制为两个 CPU 线程。
- ARM64 APK 340665478 字节，比前一通用包减少 63%；相同签名、versionCode 702001。运行库链接目标和签名检查通过。按用户要求不做模拟器实测，降温及手机交互效果仍需实机反馈。证据：`validation/mobile-release.json`。
- 下载：https://litter.catbox.moe/yl1iwv.apk （Catbox Litterbox，72 小时有效）。

## 前期移植记录

除用户明确排除的 Discord 外，公开 preload 契约的源码接入审核完成，已生成签名 release APK 并完成安装包静态校验，用户要求停止自行测试，已停止模拟器；APK 已上传 Catbox Litterbox 交用户安装验证。`build:android` 的源码完整度检查仍保留，运行验证独立记录。

上游：`chthollyphile/folia-major`，v0.7.20，提交 `e1fcc9a8b9b891618d87c513c4da6519a5c22d23`。

## 源码已接入

- Capacitor 8 Android 容器，compile/target SDK 37。Node.js 24 独立进程；可执行文件安装到 nativeLibraryDir，认证令牌仅原生与后端持有。ARM64 与 x86_64 运行库均通过 ELF 16 KiB 对齐检查，WebP 库重新编译，Spotify N-API 模块分别交叉编译。
- 网易云、QQ、酷狗、波点原后端；原登录诊断与自检。YouTube Music 的原 API/音频实现与独立禁网脚本沙箱；Spotify 原 API/音频实现与原生依赖。YouTube Music 登录接入独立 GeckoView 进程、私有原生凭据交接及原登录状态机；未验证真实 Google 账号登录。
- 原 AI 客户端、提示词、结构校验、密钥加密与设置。Android Keystore 包装主密钥；可选择安卓系统 HTTP/SOCKS 代理。
- 原 Stage、歌词 API、OBS SSE 源、音频转码、统一音频缓存预算、封面缓存验证、本地封面协议、调试日志与内存采样实现。部分主进程函数由 AST 从固定桌面源码提取，避免复制后行为漂移。
- 模型管理使用原 manifest/hash 校验，内置 Python/NumPy/ONNX Runtime；Beat This 与 Demucs 推理接线。Beat This 已在 Android 17 组件测试中运行；Demucs 实际推理尚未通过。
- Android SAF 可持久目录授权、目录遍历、文件读写、seek/truncate/abort、文件暂存和私有目录浏览。真实原生文件选择与确认对话框。
- 原 Folium 模组管理、Node 入口、授权、RPC、存储、网络、文件授权与协议；Android 多窗口、隐藏虚拟显示器、PixelCopy 逐帧捕获和 FFmpeg 导出接线。模组导出尚未在应用中端到端验证。
- 媒体前台服务、MediaSession、锁屏/通知操作、音频焦点、唤醒锁、录音活动监测。预见性返回处理开始、进度、取消和提交，根页面交给系统返回动画。上述应用级行为尚未完成设备验证。
- 悬浮窗口、穿透、透明、遥控窗口、播放状态交接、原生主题与系统壁纸服务接线。壁纸服务复用原 OBS 渲染器与配置/时钟流。复用桌面拖动区域接入原生窗口移动，按钮等交互区排除；遥控窗独立最近任务、原生模糊、显示变化通知及渲染器退出恢复已接入。窗口和壁纸功能尚未完成设备验证。
- 上游 Realeco/Limo/Cielo 通道检查与滚动版本元数据解析、设置变化生效及旧请求取消、兼容 APK 下载、摘要校验、安装前包名/签名校验、系统安装授权。上游版本是否提供 Android 安装包由实际 release assets 决定，不能把桌面更新包安装到安卓。
- 保留原 14 种歌词动画、6 类背景、着色器、全部参数和渲染器；未降低移动端画质。使用硬件加速和系统高刷新率请求。设备视觉一致性及帧率尚未验证。

“源码已接入”不等于整个功能已测试通过。不得据此宣称桌面与 APK 没有任何差异。

## 已有验证证据

- 已生成 v0.7.20 release APK（919896162 字节），v2 签名校验通过，compile/target SDK 37，ARM64/x86_64。APK 内及两套运行包共 1120 个 ELF 均通过 16 KiB 检查，zipalign 检查通过。签名为社区移植构建，非上游官方签名。详见 `validation/apk-artifact.json`。

- Android 17 / API 37 / 16384 字节页面的 x86_64 模拟器内：Node 24.18.0、Python 3.14.6、NumPy 2.5.4、ONNX Runtime 1.31.0 实际运行。
- ONNX CPU 执行一次 float32 Add 模型，结果 `[3.25, 2.0]`；Spotify 原生模块成功 dlopen；FFmpeg 9.0.2 编出 605 字节的 VP9 测试视频。没有使用登录凭据，没有验证第三方登录或付费播放。
- 证据元数据：[validation/android17-native-components.json](validation/android17-native-components.json)。这些是组件测试，不是 APK 安装或应用运行验证。
- 原生 Java 编译通过（AGP 9.1 / Gradle 9.3.1；含独立 GeckoView 登录、私有凭据交接、原生长轮询调度、窗口关闭同步）；后续修改须再次编译。
- TypeScript 类型检查通过。下载缓存已从类型检查范围排除，防止误扫 npm/原生依赖树。
- 安卓适配完整单元集：14 个文件、32 项通过；包含持久文件选择、句柄恢复、安卓功能入口、事件、返回目标、凭据、缓存、模型目录、导出和窗口边界。原命令面板 86 项另行通过；原 Discord 5 项与封面 URL 3 项此前通过。另有 2 项真实 Chromium 交互测试通过（返回取消/焦点分发、窗口拖动区域），不能代替 Android 原生手势测试。
- 早期已运行原 AI/凭据/后端 68 项相关回归测试；近期缓存、模型、导出和登录诊断变更的回归结果见执行日志。

## 用户调整范围

2026-10-17 用户明确要求「不管discord了」，Discord 富状态从本次交付范围中排除；不再作为 APK 构建前置条件，不计作已实现。

## 尚需完成

- Android 17 上的应用安装、冷启动、进程重建、设置保留、本地音乐扫描、全部歌词/背景动画、后台播放及手势提交/取消测试。
- 原生窗口、遥控窗、透明/穿透、虚拟显示器导出、壁纸和系统文件写入端到端验证及发现的问题修复。
- 窗口导出尺寸和恢复、字体诊断已接入 WebView CDP，尚需应用内验证。Discord 已按用户指令排除。
- 原版 Beat This 权重已在 Android 17 模拟器上运行一次合成输入推理，所有输出有限；详见 `validation/android17-analysis-models.json`。Demucs 合成输入探针在无硬件加速模拟器中长时间未返回，已终止；尚未验证通过。模拟器还出现系统进程重启，应用级验证环境仍需修复。ARM64 运行验证和第三方平台登录/播放验证。无账号的项目需明确验证范围。
- 接口注册审计见 `validation/desktop-contract-registration.json`：141 项后端注册、4 项原生 facade；该报告仅验证注册，不代表运行正确、原生能力可用或全量移植完成。
- `portCoverage.json` 已根据逐项源码映射更新，见 `validation/source-contract-review.json`；设备验证标记仍独立保留，不能将源码映射或注册审计当作功能运行证明。

## 构建准备

JDK 21、Node >=24、Python 3、Android SDK 37、NDK、Rust Android targets、CMake。`ANDROID_NDK_HOME` 指向 NDK，可用 `CMAKE` / `CARGO` 指定工具。

```sh
npm ci --ignore-scripts
npm ci --prefix packaging/android/runtime --ignore-scripts
npm run build:android:native
```

只有源码功能接入完成、清单据真实实现更新后才运行 `npm run build:android`。构建完成还须安装测试、签名校验、记录 APK SHA256，然后交付。
