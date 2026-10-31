# Android 渲染与播放性能审查方案

日期：2026-10-24（北京时间）。基线：mobile.8 工作区。范围扩展至整个项目的代码索引与调用链；逐项标明精读证据，不声称已逐行审完所有文件。本轮只读实现，发现即追加本文件与工作日志，不构建、不修改实现。

用户反馈：滑动、捏合仍闪；播放器返回主页闪一下；播放有音频卡顿。硬约束：不得降级或删除动画及特效；允许提出 Android 原生组件方案。代码风险与实机根因分开，未经 trace 不承诺修复或节电比例。

## PERF-01 — 原生播放服务没有承载解码与输出

- 证据：`src/platform/android/installAndroidMediaSession.ts` 的 sync 扫描 HTML audio，10 秒转发一次播放快照；`android/app/src/main/java/top/izuna/foliamajor/FoliaPlaybackService.java` 仅持有 MediaSession、通知、WakeLock，控制操作回调 JS；没有播放器实例。
- 判断：现有前台服务不能把真实播放从 WebView 生命周期和页面控制链解耦。此为架构事实；不能由此推导 DOM 阻塞一定造成音频 underrun（Chromium 媒体线程与 JS 不同）。
- 方案：以 Media3 ExoPlayer + MediaSessionService 承载 Android 音频，原生时钟为真源，前端只接收离散状态和时间锚点；同一时刻只允许一个输出与焦点拥有者。保留歌词与所有音频响应特效，需要设计原生 PCM/FFT 摘要通道，不逐采样跨桥传输；保留 URL 鉴权、Range、跨曲、倍速、淡入淡出和缓存语义，功能对齐后才能替换。
- 后续验证：对齐卡顿时间点的网络缓冲、AudioTrack underrun、焦点事件、WebView 长任务；本轮未运行实机采样。

## PERF-02 — 既有 Android 样式已经关闭部分效果，与本轮约束冲突

- 证据：`src/platform/android/androidPhone.css` 对 seam/tab/home 设置 `backdrop-filter: none`，对 `.lattice-root::after` 设置 `display: none`，捏合时关闭 tile transition；mobile.8 的 `BravaisTile.tsx` 还跳过捏合中新图块入场。
- 判断：这些是已存在的效果裁减，不能再作为本轮优化方案。全屏背景玻璃与移动内容同时合成的成本仍需测量；关闭特效没有解决用户闪烁反馈。
- 方案：先建立桌面/手机效果契约清单，恢复等价效果时用有限区域实时背景采样、共享渲染源、缓存不变材质；新可见图块保留正确的动画相位，而非从零重播或直接删动画。原生 RenderEffect/RuntimeShader 或 Compose 实现必须采样真正背景，不能再次用 WebView 双重硬件绘制。
- 验证：效果参数和动画时间线逐项比对；本轮不修改已有规则，也不声称当前效果完整。

## PERF-03 — 全局 RAF 的“静止”判断不等于动画完成

- 证据：`installAndroidPresentation.ts` 的 interact 在最后输入后 1500ms 把 interacting 设为 false；sync 只看播放器视图和输入状态，调用 setAndroidFrameActivity。`frameRateLimiter.ts` 在 idle 时无条件选择 20 FPS，包含用户选择 off 的情况；其注释说明 Framer Motion 可能提前捕获原始 RAF。
- 判断：惯性、页面切换、持续效果是否完成没有参与 idle 判定，可能出现部分动画降为 20 FPS、部分仍走原始 RAF 的不同节奏。不是已证明的闪白原因；也不满足“不降级动画”的新约束。
- 方案：取消以最后输入时间代表整页静止的策略，建立显式可见动画/手势/转场活动租约，活动动画遵循用户选择的帧率与统一帧时间；仅对无视觉变化的工作按脏标记停止调度。保留动画速度、曲线、粒子和特效质量。
- 验证：长惯性、自动转场、首页持续背景、120Hz 屏幕上比较各动画时间戳及 missed-frame，而非只看平均 FPS。

## PERF-04 — 返回主页使用固定计时卸载背景，缺少首帧就绪契约

- 证据：`src/App.tsx:2364` 用 effect 恢复 isHomeFullyHidden，首页容器在 `2685` 由 display:none 恢复、同时开始 0.25 秒淡入；`useLibraryOcclusionSettled.ts` 固定等待 300ms 后允许 `playerVisualizerMount.ts` 卸载底层 visualizer。判定没有检查首页封面、GPU 纹理或实际呈现帧是否就绪。
- 判断：时间过去不等于资源已经呈现，资源紧张时存在交接空窗风险；手机上的一次闪烁还不能仅据此确诊。display:none 恢复还会重新产生布局/绘制工作。
- 方案：保持原转场曲线和时长，准备阶段确保目标可见图块解码、布局和渲染就绪，再启动同一转场；由动画完成事件与目标帧就绪共同释放原背景。对不可见场景保留有界运行时状态和纹理缓存，避免重建全部资源。不要在背景仍通过透明玻璃可见时暂停它。
- 验证：分别标记路由变化、显示恢复、资源 ready、动画完成、旧背景释放，采集帧时间线；验证低内存与快速往返时无空窗。

## PERF-05 — 音频响应桥每帧分配数组，频率映射写死

- 证据：`usePlaybackVisualizerBridge.ts` 的 updateLoop 在播放时每帧 new Uint8Array，在暂停呼吸分支也每帧创建空数组；频带索引固定除以 21.5，未使用 analyser.context.sampleRate / fftSize。循环无可见消费者检查。
- 判断：确定存在持续分配与非通用频率映射；单数组不大，不能把它夸大为 8W 或音频卡顿唯一原因。不同采样率下视觉频带响应可能偏移。
- 方案：预分配双/多缓冲频谱并明确订阅者持有期，避免复用同一引用导致 MotionValue 丢更新；空谱复用不可变常量。频率索引用实际采样率计算。按可见特效消费者订阅启停分析，保留所有仍可见的音频响应和呼吸动画，不降低其帧率。
- 验证：分配速率、订阅者更新、44.1/48kHz 频带值及特效一致性。

## PERF-06 — 原生桥空闲仍轮询，回复线程池没有显式上限

- 证据：`FoliaNativeDispatcher.java` 每次无任务 sleep(150) 后再次 `_nativePoll` RPC；回复/代理查询/进程测量共用 newCachedThreadPool。存在长期空闲唤醒和请求激增时线程膨胀风险。
- 判断：请求上界和待处理数量需要量测；不能从线程池类型直接断言已产生大量线程。与播放共处时不应让后台元数据/测量抢占播放资源。
- 方案：使用可取消长轮询或本地事件通道唤醒，有界执行器、队列上限与反压；区分交互、播放控制和后台扫描优先级；完整保留原生功能与结果回传，不能简单丢弃请求。
- 验证：空闲唤醒次数、队列深度、线程数、取消/重连和后台播放控制可靠性。

### PERF-06 调用链校正（继续读服务端后立即补记）

`packaging/android/runtime/events.cjs:waitNative` 已有 25 秒长轮询。因此上文“长期空闲唤醒”不能按 150ms 推算，150ms 是长轮询返回空之后的退避，并非 6.7 次/秒。撤回把轮询频率当高功耗问题的判断，不重复实现已有长轮询。保留有界回复执行器/请求反压审查项；需进一步确认超时、断开连接时等待者清理和请求实际速率。

## PERF-07 — Node 二进制桥同步文件 IO 与额外全量复制

- 证据：`packaging/android/runtime/wire.cjs` decode 使用 readFileSync、unlinkSync、ArrayBuffer.slice；encode 使用 writeFileSync。`runtime/main.cjs` 的 RPC 请求处理调用 wire.encode/decode，与协议处理共用 Node 事件循环。
- 判断：大二进制 RPC 期间会占用事件循环并出现整块内存复制；是否恰逢音频协议补数据取决于源平台与操作，尚未实测。
- 方案：二进制桥异步化、有界分块/文件句柄转交，维持所有权、清理和权限校验；大音频分析隔离至 worker/独立进程，播放流留独立优先通道。禁止将大数据改回 JSON/base64。
- 验证：事件循环延迟、最大缓冲占用、同时分析/切歌/滑动时的流缓冲；核对网络请求仍保留 Range。

## PERF-08 — 批量设置会重复整文件同步持久化

- 证据：`packaging/android/runtime/platform.cjs` Store.set 接收对象时逐键递归 set，每一键 persist 都 JSON.stringify 全量 values、writeFileSync 和 renameSync，并 structuredClone 后广播；`runtime/main.cjs` 的设置 persist 也同步写文件。
- 判断：批量导入或连续设置会放大 IO 与序列化，可能阻塞同进程协议流；不能解释用户完全不操作设置时的所有卡顿。
- 方案：批量事务只序列化/写入一次，串行异步原子落盘，合并短期重复写入并提供关键凭据即时 flush；保持事件顺序、崩溃恢复与导入导出语义。
- 验证：批量导入写入次数、进程 event-loop 延迟、异常退出恢复和凭据持久化。

## PERF-09 — mobile.8 图片队列只限活动数，没有生命周期与待处理预算

- 证据：`wallArtworkQueue.ts` waiting 无限 push，无取消、超时、可见性优先级；`useWallPosterArtwork.ts` cleanup 只阻止 setReady，已经排队的 decode 仍执行；pickDisplay 冷启动直接返回目标 URL，初次 CSS 加载绕过队列；失败 URL 存入 failedVariants 后不按瞬时故障重试。
- 判断：快速滑动/缩放可能继续为离屏图解码，两个慢请求可阻塞后续清晰图；“并发 2”不是总内存预算，也没有解决首帧图块空白。上轮工作日志已承认冷加载缺口，这次补全队列生命周期问题。
- 方案：按 URL 去重、订阅计数、任务代次、可见优先级及估算解码字节控制队列；零消费者任务取消/移出，暂时错误有界重试；将首载纳入资源管理，旧画面直到新图可呈现才释放。保留全画质目标，不能再靠固定 1024 上限压画质来满足性能要求。
- 验证：连续快速往返的队列长度、离屏任务数、首次加载并发和纹理占用；不把 URL 标记缓存当成已驻留 GPU 纹理。

## PERF-10 — 连续缩放与整墙栅格假设冲突，裁剪提交仍非原子

- 证据：`wall.css:81` 明确原设计 scale 仅随 resize 变化；`wallView.ts:formatWorldTransform` 只对平移做像素对齐，scale 连续传入。`useBravaisCamera.ts` 先 renderFrame 写相机，再 publishCullBounds 的 setBounds；`BravaisStage.tsx:266` 依赖 bounds 重建 slots；`BravaisWall.tsx` 依集合挂载/卸载 tile。mobile.8 移除了一个 RAF，并未使 React 提交与相机显示原子化。
- 判断：高负载时相机已露出区域、图块尚未提交仍可能存在；连续 scale 造成的 raster/texture churn 是主要待验证假设。平移像素取整不能证明缩放栅格稳定。
- 方案：以手势期间可见范围的保守包络提前准备有界分块，保留旧/新覆盖重叠直到新帧 ready；将相机、裁剪和呈现划分明确代次。原生候选为有限纹理块的 RenderNode/Canvas 或 GPU 场景渲染，单一场景同时输出墙、翻牌、倾斜、玻璃采样。栅格准备与几何运动解耦，但最终清晰度、连续动作与全部特效不变；禁止再次强制提升整张无限墙。
- 验证：区分掉帧、checkerboarding、透明动画和 renderer 重启；采集 RasterTask、tile eviction、GPU 内存与 React commit，对齐每次闪的帧，不能靠平均帧率归因。

## PERF-11 — 分析 worker 失败后永久回退主线程

- 证据：`src/services/automix/analysisOffThread.ts` decline 永久置 offThreadDeclined；调用者回退相同分析函数在本线程执行；postMessage 没有 transfer list，会结构化复制 PCM。profileService 已串行分析，不能误报为无限并行。
- 判断：只在 automix 分析启用且 worker 失败等条件下触发；目前没有用户日志证明发生。可能形成 UI 长任务与大缓冲复制，不能直接等同 AudioTrack underrun。
- 方案：可恢复 worker 池或原生后台分析，明确 PCM 所有权后 transfer，失败隔离并有界重试；Android 不在交互主线程同步执行整段分析。保留分析精度和混音能力，不以关闭分析功能解决。
- 验证：worker 异常路径、PCM 转交后的双 deck 数据完整性、长任务和分析延迟。

## PERF-12 — 原生刷新率提示与用户帧率设置脱节

- 证据：`MainActivity.java:onCreate` 在 API35+ 固定 `WebView.setRequestedFrameRate(60f)`；前端 frameRateLimiter 支持 60/90/120/off，当前原生调用不读该设置。
- 判断：这是 Android 刷新率提示，不是保证硬性锁 60Hz，但与前端 90/120/off 意图不一致。不能把更低刷新率当成保留同等动画效果的优化。
- 方案：原生提示与前端用户设置、实际显示模式和可见动画活动同步；优化每帧开销，在系统允许时保持用户期望帧率。系统节能限制单独记录，不篡改动画时长。
- 验证：读取实际 display refreshRate、呈现间隔和前端时间戳，区分系统选择和应用提示。

## 优先实施顺序与证据门槛

1. **播放连续性优先**：先测真实 underrun、缓冲、焦点和源重载原因；隔离 PERF-07/08/11 重工作，原生播放器按 PERF-01 做完整功能对齐。不允许未补齐 EQ/双 deck/分析/歌词时钟就切换。
2. **滑动与捏合**：PERF-10 的相机/图块呈现协议配合 PERF-09 资源生命周期；先确认闪的是空白图块、整层合成还是动画透明帧，再决定保留 WebView 或迁移有界原生场景。
3. **返回主页**：PERF-04 目标首帧准备及转场完成协议；固定延迟不作资源就绪替代。
4. **保留全部视觉**：PERF-02/03/12 的历史降级与刷新策略需重新设计；优化重复计算、布局、采样和资源复用，不降低帧率、模糊/折射质量、画质或删动画。原生化必须单一渲染源，完整保留命中测试、可访问性、主题、手势、翻牌与歌词视觉。
5. **必要后续实机证据**：同一首本地曲目排除网络，再用在线源对比；记录静止、单指滑动、捏合、返回主页四段，关联 Perfetto/Chromium trace、音频 underrun、buffering、GPU/CPU 热状态。此处只是后续验证方案，本轮没有运行测试或采样。

## 覆盖与未决项

已把检索范围扩展到前端组件/歌词与背景、stores/hooks/services/workers、Electron 后端、Android 原生与 Node runtime、API、worker 和 sync-server，建立 2279 文件索引并扫描 208 处选定热点匹配。详见 PERFORMANCE_REVIEW_SCOPE.md。索引/检索不等于已逐行阅读全部代码。

本轮精读了墙相机/裁剪/封面、页面交接、播放/频谱桥、分析 worker、Android 媒体服务/系统栏/原生调度、Node RPC/二进制/存储等关键链路。尚需逐模块深入：各歌词模式与 shader、各平台在线音源恢复/缓存、全部音效图、导出/多窗口、模组运行时与同步服务。没有将未读模块标为通过，也没有确定唯一实机根因。

明确排除误报：服务端已有 25 秒长轮询；媒体协议响应使用 stream.pipe 而非一律整曲缓冲；automix 分析已有串行 worker；Sora 背景暂停时已有按需失效绘制；Latent 有样式写入缓存。后续方案须复用这些现有机制。

## PERF-13 — 部分音源播完再整曲下载缓存，可能与下一曲竞争

- 证据：`src/services/playedTrackCache.ts:cachePlayedTrackAssets` 对非 blob 且无平台自管缓存的源，在未命中缓存时再次 fetch(src)、response.blob()，再执行缓存写入。调用来自 usePlaybackAudioBridge 及混音交接结束路径。
- 判断：此为有条件的整曲再下载/内存实体化，不是所有平台都如此；可能与下一曲起播竞争带宽、内存和存储，尤需关联“切歌附近卡顿”，不能解释每次滑动。
- 方案：原生音频数据源提供流式磁盘缓存与 Range 复用，播放已获取数据直接复用；暂留 WebView 时把缓存转为有界后台任务，播放缓冲不足优先保障播放，恢复后继续完成。保留离线缓存和原质量音频，验证授权 URL、质量级别及完整曲目校验。
- 验证：下一曲起播时的重复下载量、内存峰值、缓冲余量；不能直接删去缓存功能。

## PERF-14 — 部分音效首次启用在 UI 线程生成大缓冲

- 证据：`src/services/audioEffects/effectSources.ts` 同步生成 3 秒双声道黑胶噪声和默认 2.2 秒双声道混响脉冲；`reverbBranch.ts:set` 初次创建 convolver 时直接调用 createReverbImpulse。
- 判断：风险集中于启用/重建音效时，音效已稳定时不是每帧生成；现有 wet 淡出和节点释放应保留。是否造成可闻卡顿需实机关联。
- 方案：后台预计算同精度脉冲/噪声，有界缓存按采样率和参数键管理，主线程仅安装完成缓冲；保持原淡入淡出与声学参数，不能删混响/黑胶效果。
- 验证：首次启用长任务和声音连续性、采样率切换、缓存上限。

## PERF-15 — 原生导出捕获在主线程编码 PNG 和写双份帧数据

- 证据：`FoliaWindowHost.java:windowCapture` 将 PixelCopy 回调指定到 main Looper，回调直接执行 saveCapture；saveCapture 同步 PNG 压缩、像素数组复制、逐像素 BGRA 转换和两个文件写入。
- 判断：只在导出/捕获激活时成立，不应当作普通首页闪烁根因；若导出与播放并行，会直接增加 Android 主线程长任务和内存压力。
- 方案：PixelCopy 完成后将位图所有权移交有界编码工作线程，完成后回收；按请求输出必要格式，保持透明度与色彩契约，导出任务反压，不丢帧或减特效。
- 验证：并行播放/导出的 UI 帧时、主线程 IO、位图回收、导出帧数与透明度。

### 后续补充覆盖

本轮继续精读音效源生成、混响支路、播放完成缓存、缓存校验和原生导出捕获，新增 PERF-13～15。目前共 15 个审查条目，其中 PERF-06 的高频轮询初判已撤回，线程池/反压部分保留。仍未逐行审完全部 2279 个文件；全量索引用于后续逐模块推进，不将扫描计数包装成完成度。

## PERF-16 — 预见性返回缩放整个 root，提交时先复位再导航

- 证据：`src/platform/android/installAndroidBack.ts` 无弹窗时以 `#root` 为 target；progress 改 root.style.scale/translate；commit 先 restore(false) 再 history.back()。
- 判断：手势期间会让墙、播放器、玻璃等整棵树共同缩放，叠加原有层变换；提交时立即恢复原尺寸，历史导航随后才处理，存在可见复位跳动窗口。属于新的返回闪动候选，尚需区分用户点按钮还是系统返回。
- 方案：只对导航中的场景层应用预测返回，保持全局播放控件和系统安全区稳定；以同一转场会话衔接手势进度、提交和目标首帧，取消时完整回弹。保留预见性动画，不跳过或缩短。
- 验证：左/右边缘返回、取消、快速提交、弹窗与播放器返回，记录 root 变换和历史事件帧序。

## PERF-17 — 前端二进制“分块”仍先整文件实体化，目录查找重复全列举

- 证据：`androidFileSystem.ts:createWritable` 先 Blob.arrayBuffer 再 64KiB 分块；getFile 读取 response.blob；child 每次 entries 全目录查询，resolve 广度遍历整个子树。`androidWire.ts` 64KiB 上传逐字节拼接字符串/base64，decode 对多个二进制值 Promise.all 并发整块读取。
- 影响：大文件导出、本地库扫描、音频分析会叠加大缓冲和大量桥接调用；分块消息不等于分块内存。条件性风险，不归因为所有空闲闪烁。
- 方案：Blob.stream/slice 有界读取，文件描述符优先，二进制传输 Worker 化/原生直通；按总字节约束接收并发。SAF 目录索引按授权/变更失效，分页列举，避免每个 child 重扫；保持句柄权限、seek、truncate、abort 语义。

## PERF-18 — 沙箱 WebView 生命周期和超时没有任务代次

- 证据：`FoliaScriptSandbox.java` 静态 WebView 用 Activity 构造、没有活动销毁清理；首次 loadData 后第二次 evaluate 可直接 run，未等 page finished；任何一个 15 秒超时都 destroy 全局 view，其他 pending 未一起结算，旧 timeout 还可能销毁后来新建的 view。
- 影响：并发 YTM 解签/超时重建可能中断彼此并保留 Activity，进而影响取音频 URL 和内存。仅关联该平台调用场景。
- 方案：显式初始化 Promise、每代隔离的待处理队列与 timeout；销毁一代时统一拒绝其任务并取消计时器，不碰新代；绑定受控宿主生命周期。继续保留禁网/禁文件和不可信脚本隔离。

## PERF-19 — SAF 大 IO 阻塞共享插件队列；失败写回会删除恢复副本

- 证据：FoliaFileSystemPlugin 的 beginWrite/finishWrite/stage/list 直接同步执行；Capacitor Bridge 使用 CapacitorPlugins HandlerThread 派发（不是 Android UI 线程，不能误报为 UI 主线程 IO）。finishWrite 以 wt 打开目标后拷贝，finally 无论成功失败都删除临时副本。
- 影响：慢 SAF 提供方阻塞同桥其他插件调用，包含播放状态/返回控制；写回中失败可能留下截断目标且失去临时恢复数据。
- 方案：文件 IO 使用有界专用执行器、单 token 顺序队列与取消；提交失败保留临时恢复副本、状态与重试入口，提供方支持时使用替换/事务语义，不能宣称所有 SAF 都支持原子 rename。

## PERF-20 — Activity 销毁后仍可能持有插件与未结算请求

- 证据：FoliaRuntimePlugin.handleOnDestroy 未清理 FoliaPlaybackService.plugin 静态引用；FoliaShellPlugin 的 io 线程池和 exportTargets/localNetworkRequests 没有销毁处理；YtmAuthProvider.pending 在启动登录 Activity 失败或无回传时没有本地过期清理。
- 影响：重建/退出后旧 Activity、PluginCall 可能被保留或收取控制事件；持续重建会积累资源。不能据此断言用户当前设备已泄漏多少内存。
- 方案：按宿主代次注册/解除引用，关闭执行器或移至 Application 级受控服务，统一完成/取消 pending；播放服务不依赖 Activity 插件存活，事件发给当前订阅者。

## PERF-21 — 虚拟导出窗口只限制边长，没有总像素/窗口预算和失败回滚

- 证据：FoliaWindowHost.windowCreate 每边允许8192，ImageReader RGBA 三缓冲，并在创建资源前 windows.put；catch 仅 failed.accept，无 host.close 回滚。单张8192² RGBA约256MiB，另有捕获位图/数组/编码缓冲，实际分配受系统实现影响。
- 影响：大导出或并发窗口可触发内存压力、renderer 被杀；创建中途失败可能残留窗口条目与已分配资源。普通首页需先确认是否有导出/辅助窗口，不能混为一谈。
- 方案：基于总像素、并发任务和设备内存的准入及排队，保持用户指定导出分辨率，通过分块/离线串行完成而不是静默缩小；资源构建失败逆序清理，生命周期幂等。

## PERF-22 — 推理超时拒绝 Promise 不等于子进程已退出

- 证据：runtime/analysis.cjs runPython 180秒超时 child.kill 后立即 reject，enqueue 后续任务即可开始；未等待 close 或 TERM 后 KILL 兜底；finally 同时删除任务临时目录。输入只限每个 chunk 大小，未限 chunks 总数，等待队列无取消。
- 影响：不响应 TERM 的推理可能与下一任务并存，破坏“串行/两线程”资源假设；临时目录清理与子进程读写存在竞争。
- 方案：超时后进入 terminating，等待退出并必要时强杀，确认 close 才释放队列/临时文件；设置总字节准入、任务取消和代次，保持模型精度与功能。

## PERF-23 — Android 更新源与实际交付仓库不一致

- 证据：runtime/updates.cjs 硬编码 chthollyphile/folia-major；实际 mobile 系列发布在 Sakurakilove/folia-major-android-apk。候选包还要求本地签名一致，不能直接用任意上游 APK 替代。
- 影响：用户可能看不到当前移植修复包，或遇到不可安装更新；属于交付一致性问题，不是闪烁根因。
- 方案：明确移植发行渠道和签名身份，更新元数据从对应仓库获取，保留用户通道偏好与原上游版本信息；不要自动切至不可信镜像或绕过签名校验。

## PERF-24 — 打包目录增量合并会残留已删除模块，覆盖检查仅核对声明

- 证据：prepareRuntime.py 将 electron/shared 用 dirs_exist_ok 合并，未先清理；随后遍历 runtime 全目录归档。checkPortCoverage.py 只对 portCoverage.json 的 implemented/excludedByUser 字符串判断，不核对方法运行行为。Node archive 又携带 dist，APK WebView public 也携带前端资源。
- 影响：被源码删除的旧模块可能留在包中；声明完整不能证明实际功能/性能完整。双份前端资源有体积成本，但辅助窗口/壁纸需要其中部分，不能粗暴删除。
- 方案：从干净 staging 按依赖清单生成包，记录源文件 hash；只去重内容一致且访问契约可统一的资源，保留所有模式/动画/辅助窗；覆盖记录区分声明、静态可达与设备验证。

## PERF-25 — 当前运行时归档前端与 APK 主前端不一致

- 证据：只读比对 android/app/src/main/assets/node-runtime.zip 中 dist/index.html 与工作区 dist/index.html，内容不同；main.cjs/events.cjs 相同。mobile.8 构建记录只执行 build:android:web、cap copy、Gradle，完整 build:android 脚本才包含 prepareRuntime。
- 影响：辅助窗口/壁纸可能读取旧 dist，而主应用使用新 dist；跨层版本混用可能造成修复未到达全部宿主、旧 hash 资源加载失败。尚需逐资源核对实际 APK 与访问路由，不能声称所有辅助窗口都坏。
- 方案：所有宿主使用同一构建标识和资源清单，一次 staging 原子打包；构建静态校验主前端和运行时引用闭包，杜绝只复制部分前端。资源去重与 PERF-24 一起做，保持全部功能。

## PERF-26 — 诊断内存采样串行排队，可能形成观察开销积压

- 证据：memorySamples.ts 每收到样本即调用 reportSelf，无 in-flight 合并；Android debugger.cjs serialize 将每次 memory 请求排入 Promise 链，每次建立 CDP、Tracing.start、requestMemoryDump、Tracing.end。采样开关默认关闭，只有启用时成立。
- 影响：慢于采样周期时排队不断增长，停止观察后旧任务仍继续；诊断本身可能污染功耗/卡顿测量。
- 方案：单飞采样并合并最新需求、关闭时取消未执行任务，标注采样开销；保留诊断功能，不把关掉用户诊断当性能修复。

## PERF-27 — 播放服务状态依赖页面事件，缺少 renderer 消失后的收尾

- 证据：installAndroidMediaSession.sync 在找不到 audio 时直接 return，且 last 在 native.playback 成功前更新；FoliaPlaybackService 只依据快照 playing 获取/释放无超时 WakeLock，rendererGone 路径未通知服务播放终止。
- 影响：renderer 异常/音频元素删除且未收到 pause 时服务可能保留播放通知和唤醒锁；失败快照没有可靠确认。不能认定当前手机所有发热来自唤醒锁。
- 方案：原生播放器作为状态真源；过渡阶段以 renderer 代次、失联处理和可确认状态同步收尾，区分真正后台播放与失联，不能定时强停正常音乐。

## PERF-28 — OBS / 壁纸事件输出没有慢消费者反压

- 证据：`packaging/android/runtime/generated/obs.cjs` 的 `sendSerializedObsEvent` / `broadcastObsBrowserSourceEvent` 对每个客户端连续 `res.write`，不处理 false、drain、积压字节或超时；音频与时钟事件均走此通道。
- 影响：仅在 OBS / 壁纸订阅启用且消费者变慢时，Node 可持续积累历史帧，增加内存、GC 和延迟，竞争播放代理资源；不能解释未启用订阅时的普通主页闪烁。
- 方案：每客户端设置有界输出，时钟/频谱采用最新状态覆盖待发送状态，配置保留顺序与版本；drain 后恢复，断线取消。修改提取源及生成器契约，不能只改生成文件。保持实时效果和目标呈现帧率，不降低动画质量。
- 状态：静态路径确认，未实施、未实机测量。

## PERF-29 — 音频与封面缓存写入没有原子发布

- 证据：`packaging/android/runtime/generated/mediaCache.cjs` 的 `writeAudioCacheEntry` / `writeCoverCacheEntry` 直接并行写最终 `.bin` 和 `.json`；读取不与写入互斥，音频读取也不校验保存的 size。封面读到元数据和内容不一致时会删除这两个最终路径。
- 影响：相同 cacheKey 的读取/写入/清理交错可能返回半首音频或将正在更新的封面误当损坏删除。属于明确的数据发布竞争；是否触发本机卡顿需结合缓存命中和写入时序。
- 方案：按 key 合并写入，临时文件完整写入后发布带版本的元数据/内容引用，读取固定版本且校验长度；清理只处理没有读写租约的旧版本。缓存目录扫描采用有界并发，保留完整音质和图片精度。
- 状态：静态竞争确认，未修改生成源或实现。

## PERF-30 — 长距离相机动画只预留终点，途中不补裁剪

- 证据：`src/library/suites/bravais/useBravaisCamera.ts` 的 `tweenTo` 在起终点合并面积超过终点视口 3 倍时将 bounds 直接替换成 destination；动画 `onUpdate` 只改 center、同步相机和写 DOM，没有 `checkCull` / `moveTo`，直到 `onComplete` 才重新裁剪。
- 影响：远距离定位/弹回等补间可能在起点图块卸载后经过未渲染的区域，出现缺块或空背景再恢复。这是独立于手势 RAF 合帧的闪屏路径，不应只继续修改 pointermove。
- 方案：保留原曲线、时长、完整图块效果，沿动画轨迹分阶段预取并将相机呈现与图块就绪代次对齐；不得用直接跳到终点或删除补间规避。复用 PERF-10 的原子呈现协议。
- 状态：代码路径确认；是否对应用户返回/滑动的具体闪帧仍待时间线关联。

## PERF-31 — 音频图初始化失败后留下禁止重试的半成品

- 证据：`src/components/app/playback/bridges/usePlaybackAudioBridge.ts` 的 `setupAudioAnalyzer` 在完整连图之前写入 `audioContextRef.current`；异常只输出日志，下次入口因 context 已存在直接返回。`buildPlaybackGraph` 会先接入 MediaElementSource，再创建均衡器/效果节点。
- 影响：若中途建图或效果初始化失败，可能已将媒体输出导入一个没有连到 destination 的图，且之后播放不会补完连接。不能把它误判成网络缓冲或用反复重建同一个 MediaElementSource 修复。
- 方案：明确 initializing/ready/failed 状态和每节点所有权；保留已经建立的源节点，失败时回滚部分节点并提供可恢复的输出连接，再重试完整效果链；输出切换采用平滑增益，恢复完成前清楚报告效果状态，不静默删除音效。
- 状态：失败恢复缺口已确认，尚无本机初始化异常证据。

## PERF-32 — 自动播放等待歌词匹配，扩大切歌静音窗口

- 证据：同一桥的自动播放条件为 `shouldAutoPlayRef.current && !isLyricsLoading`；音频已有 source、可开始缓冲/播放时仍受歌词网络或分析完成约束。
- 影响：歌词慢请求会延迟首次播放或曲间启动；这是切歌体验问题，不足以解释一首歌中间的音频 underrun。
- 方案：音频就绪与歌词就绪解耦，音频按播放意图、音源代次和 automix 时钟启动；歌词到达按实际媒体时钟同步加入，保留匹配提示、完整歌词动画和自动混音 hold 规则。
- 状态：代码条件确认，实施前需核对产品是否存在主动等待歌词设置。

### PERF-30 范围补充

`PosterWall.reserveBounds` 与 `useWallCameraPan.panTo` 也采用超过 3 屏只保留终点、途中不重裁剪的组合；同一方案应覆盖 Lattice 与 Bravais，避免只修一种墙面。

## PERF-33 — 壁纸渲染器可见性与创建生命周期没有闭合

- 证据：`FoliaWallpaperService.FoliaEngine` 每次 `onSurfaceChanged` 都销毁并新建 VirtualDisplay、Presentation、WebView；只在 `onVisibilityChanged` 当下向已存在的 view 发事件，没有保存 visible，也未在新页面加载后补发。壁纸是普通 WebView，无 Capacitor bridge；`installAndroidPresentation` 在非原生 Capacitor 上直接返回，无法消费这个自定义可见性事件。
- 影响：创建与隐藏交错可能丢失隐藏状态，重复 Surface 回调会重建完整 JS/纹理资源；是否后台持续绘制还取决于 WebView/Surface 平台节流，不能仅凭 `onPause()` 推断全部 JavaScript 已暂停。仅限启用动态壁纸时。
- 方案：引擎保存可见性及 surface 代次，页面 ready 后同步当前状态；相同 surface/尺寸复用，尺寸改变优先 resize；壁纸页面具有独立于 Capacitor 的宿主可见性订阅，在不可见时停视觉计算、恢复时按同一播放时钟呈现完整效果。取消旧代创建工作及恢复回调。
- 状态：事件丢失和入口不匹配已确认；实际后台功耗待测。

## PERF-34 — YTM 缓存淘汰未保护正在播放的下载

- 证据：`electron/ytm/audio.cjs` 的 ready LRU 以整曲 contentLength 计费，淘汰回调立刻 `entry.stop?.()`；`trackBuffer.cjs` 的 LRU 没有 reader / playback pin。新曲预加载、换音质或另一读取请求进入缓存时可以淘汰仍被媒体元素读取的旧曲。TrackBuffer 为每曲一次性 `Buffer.alloc(total)`，单曲允许 256 MiB，且 newest 超预算仍保留。
- 影响：自动混音/并行加载时可能中止尚未下载完的当前曲，已缓冲部分播放完后断流；字节预算也不是实际总驻留内存硬上限，因为 reader 仍引用被淘汰的 TrackBuffer。限于 YTM 音源，不能解释所有平台。
- 方案：播放中和混音两侧 reader 使用租约保护；无引用下载才可取消；以实际驻留字节计费、使用文件分段缓存与范围读取，保留所选音质；配额不足时排队预取而不是中止当前曲。取消 reader 时同时解除 waiter，避免等到下一块或 stall 才释放。
- 状态：淘汰/下载交叉路径确认，未进行音源实测。

### PERF-25 只读资源闭包核对

- Node 归档 `dist/index.html` SHA-256 前 16 位 `0d355151d2b39890`，工作区主前端为 `65b25da0e6607d49`。归档入口引用 `assets/main-D6ue12qO.js`、`assets/main-BVQXSBPC.css`；这些资源在归档内存在，但在主 WebView 的 public 目录不存在。
- 因各自资源仍齐全，当前证据证明的是两个宿主使用不同构建，并不能直接断言已经发生 404。必须按实际路由检查混用，避免把版本不一致夸大成必现启动失败。
- 复制到 runtime 的 electron 源文件逐字节比对当前全部相同，没有发现本次残留旧文件；PERF-24 的增量合并问题属于构建策略风险，当前版本尚未检出该类残留。

### PERF-32 调用链校正（发现后立即记录）

继续读 `src/services/onlinePlayback.ts` 发现：自动寻找“最佳歌词”之前已有 `onDone()`，会先释放自动播放。因此撤回“整个最佳歌词搜索都阻塞音频”的表述。仍存在的是初始 `omni.getLyrics`、歌词状态/缓存读取之前的等待；方案只针对这一剩余依赖，不重复移除已经解除的最佳匹配阻塞。

## PERF-35 — 原生媒体会话的进度拖动没有接收者，混音时钟也未统一

- 证据：`FoliaPlaybackService` 声明 ACTION_SEEK_TO 并发送 `seekto`；全 src 检索及 `useMediaSessionBridge` 阅读确认只注册 play/pause/previous/next，没有 seekto handler。`installAndroidMediaSession` 用 DOM 中第一个未暂停 audio 取 position，而共享媒体桥已经通过 `getDisplayAudioElement` 识别混音中正在显示的曲目。
- 影响：锁屏拖动可能显示可操作但无效果；混音双 deck 时原生曲名和进度可能来自不同歌曲。不应靠增加通知刷新频率补救。
- 方案：将原生媒体控制接到同一 transport port，seek 复用混音识别、时长限制、播放意图规则；metadata、时钟、播放状态共享同一个 source generation / display deck。保留所有控制和混音。
- 状态：缺少 seek handler 已确认，混音显示错配为条件性风险。

## PERF-36 — 顶部安全区只有瞬时脚本注入，页面重载可能丢失

- 证据：`MainActivity.onCreate` 的 WindowInsets 回调只通过 evaluateJavascript 写当前 document 的 `--folia-safe-top`，并返回 CONSUMED；`FoliaWebViewClient` 没有在新页面 ready/finished 后同步当前 insets。`androidPhone.css` 多处直接使用该变量，默认 0。
- 影响：insets 在前端文档加载前到达、页面重载或 renderer 恢复后，若没有再次触发原生 insets 回调，控件可能顶到状态栏下；这与状态栏背景透明是两个独立问题。
- 方案：原生保存最新窗口 insets，bridge ready 时可查询并订阅；加载、恢复、旋转、输入法变化均按窗口代次同步。使用同一布局坐标系处理 CSS px / density，保留沉浸式背景及安全触摸区域，不增加实色白条。
- 状态：缺少页面重建后的回放路径已确认，具体设备触发时序待测。

### 安装包体积只读量化（不构建）

当前已有 release APK 的 ZIP 条目压缩大小：native-runtime-arm64-v8a.zip 159,228,765 字节；Gecko libxul.so 65,265,394；node-runtime.zip 36,980,888；Node runner 14,808,115；Gecko omni.ja 14,535,510。优化优先核对原生运行时依赖闭包和两个前端副本；不能将 YTM 登录用 Gecko 或分析模型直接删除后宣称功能等价。`minifyEnabled false` 可作为 R8/资源精简研究入口，但启用前需保留 Capacitor 反射、JS interface、Gecko/JNI 注册和插件入口契约。

## PERF-37 — 暂停媒体没有暂停独立音效源

- 证据：`noiseBranch.ts` 创建 loop AudioBufferSource，`wowBranch.ts` 创建持续 oscillator；只在效果 amount 归零或 dispose 时停止。`usePlaybackTransportController` 暂停 HTMLAudioElement，`playbackFade.ts` 在暂停后 150ms 又把总 fade 恢复为 1。全 src 未发现 AudioContext.suspend 调用；效果 apply 也没有播放状态参数。
- 影响：打开黑胶噪声时，媒体暂停后独立噪声仍可能送到输出；音效源和 DSP 仍运行，界面/原生服务却认为 paused。是否能听见取决于当时 context、系统焦点和音效设置。
- 方案：为完整音频图建立播放/暂停生命周期，保留尾音和原定淡出后冻结独立源或暂停 context，恢复时先恢复时钟和相位再淡入；双 deck、导出和预览用显式租约避免误暂停其他消费者。保留噪声、抖晃、混响等全部音效。
- 状态：独立源与 transport 脱节已确认，未测量实际暂停功耗。

## PERF-38 — 本地库增量扫描在比较修改时间前已读取所有音频正文

- 证据：`localMusicService.ts:buildSnapshotTree` 对每个相关文件调用 `getFile()`，只为取 name/size/lastModified，并把 File 保留在 `filesByPath`；随后 `collectImportDiffPlan` 才比对签名决定哪些文件有变化。Android 的 `AndroidFileHandle.getFile()` 明确 fetch 整个 content URI 并 await response.blob()。
- 影响：桌面文件句柄廉价的元数据路径在 Android 上变成整库内容读取，即使没有歌曲变化也触发大规模 IO、Blob 驻留或临时存储；与正在播放/解码竞争，可能是导入库后后台发热的放大因素。不得按 File.size 总和直接声称所有字节都在 JS heap，Blob 的实际存储由 WebView 决定。
- 方案：原生 DocumentFile/MediaStore 元数据扫描生成轻量索引，先比较 revision，仅变更文件按需范围读取解析；音频播放直接使用持久 URI/文件描述符及 Range 通道，不为播放构造整曲 Blob。扫描按字节预算调度、提供取消和播放优先级，保留完整本地库与封面/歌词解析。
- 状态：整库读取路径已确认；是否用户开启本地自动扫描尚未知。

## PERF-39 — 元数据 Worker 崩溃后请求没有结束路径

- 证据：`src/utils/localMetadataWorkerClient.ts` 只注册 onmessage；callbacks 没有 timeout、onerror、onmessageerror 或终止清理。postMessage 同步抛错时已插入的 callback 也不会移除。
- 影响：Worker 初始化脚本失败、内存压力下崩溃或异常消息会使导入/补封面等待不结束，关联 File/Blob 和回调可持续被引用；后续请求仍复用这个 worker。
- 方案：为 Worker 生命周期和请求分别设置代次、完成/失败/取消通道；失败时集中 settle、释放引用、重建 worker；有限重试可定位到单文件，不把整个解析切回 UI 主线程。保留全部元数据和封面能力。
- 状态：错误路径缺口确认，未运行故障注入测试。

## PERF-40 — 本地库自动观察没有 Android 文件句柄适配

- 证据：`localLibraryAutoScan.ts:95–102,219–246` 只探测浏览器 FileSystemObserver，并将目录 handle 直接交给原生 observe；Android 的目录对象由 `androidFileSystem.ts` 实现，未提供 ContentObserver/MediaStore 观察入口。
- 影响：没有浏览器观察 API 时功能标记 unsupported；即便提供该 API，自定义 JS 句柄也不能因此成为浏览器原生文件系统句柄。不能假定 Android 已具备桌面自动扫描能力，也不能用这一未建立的后台观察路径直接解释启动发热。
- 方案：按 SAF provider 能力选择 ContentObserver 或轻量元数据差分，生命周期绑定目录授权和订阅；合并变更后复用 PERF-38 的增量索引，保留自动扫描能力，禁止高频全库正文轮询。
- 状态：平台适配缺口确认；PERF-38 的整库 IO 结论适用于手动导入/刷新等实际调用，后台自动触发需另证。

## PERF-41 — 连续切换样式可能丢弃仍占主要画面的旧层

- 证据：`styleTransition/layerTransition.ts:nextShownLayers` 在 current.waits 为 false 后只保留 current 与 next，并不区分 current 正在 enter 延迟/低透明度阶段；softFocus 的 enter 有 80ms 延迟。A→B 转场刚启动又切 C 时，A 被移除，B 可能尚未可见；C 还在等待首帧。
- 影响：快速切歌词样式/背景可能短暂露出底层。它不是已证明的双指或普通滑动根因，不能混为同一个问题。
- 方案：层所有权以实际可呈现覆盖为准；新切换先保留当前合成画面对应的活层，接续现有动画曲线，直到接替层 ready 且覆盖可见区域再释放。明确层资源预算与连续切换队列，保留所有动画，不靠取消过渡解决。
- 状态：状态机路径确认，具体闪帧仍需后续实机证据。

## PERF-42 — 后端启动超时没有终止或替换仍存活的失败启动代次

- 证据：`FoliaRuntimeHost.start` 启动进程后立即置 launched=true；等待 ready 60 秒超时只抛异常。下次调用只有 nodeProcess 已退出才清 launched，存活但卡住的启动不会重新执行；ready 也没有进程代次标识。
- 影响：卡住的后端可使页面重试仍等待同一进程，表现为长期无法进入而非可恢复重试；不能认定这是用户现有黑屏的原因。已存在 ready 原子发布修复，不重复归因空 JSON。
- 方案：共享 single-flight 启动状态机，携带进程代次与健康握手；超时进入 failed，等待旧进程完全退出并清理其 dispatcher 后允许有界重启。播放中恢复另循源状态协议，不能无条件杀进程打断音乐。
- 状态：启动错误恢复路径确认，只读。

## 本轮收尾与修复顺序

用户要求快速收尾，本轮截至 PERF-42。每项发现均已在发现时写入方案及 WORKLOG；PERF-06、25、32、38 的证据边界与纠正保留，不把 42 项全部当成用户故障的已证实根因。

| 顺序 | 工作 | 对应条目 | 完成条件 |
| --- | --- | --- | --- |
| 1 | 保护正在播放的下载、音频图失败恢复和暂停生命周期 | 34、31、37、22 | 当前曲及混音两侧不断流；失败可恢复；暂停后独立音效正确收尾 |
| 2 | 统一相机与图块呈现代次，修复动画路径裁剪及返回交接 | 10、30、04、16、41 | 保留完整动画与实时背景，旧画面只在接替画面可呈现后释放 |
| 3 | 移除同步大 IO、整库正文扫描和无界资源排队 | 07、08、09、17、29、38、39 | 播放优先、按字节预算调度、取消与失败都释放资源 |
| 4 | 统一活动动画时钟与宿主生命周期 | 03、05、12、18、20、27、33、36、42 | 无逐帧无效分配，恢复安全区与可见性状态，后台资源有明确所有者 |
| 5 | 评估功能等价的原生播放/渲染与发行精简 | 01、02、23、24、25、35、40 | 所有音效、混音、歌词、实时玻璃能力对齐后替换；包体优化不删功能 |

### 阅读覆盖与限制

- Android 自有 Java、前端 Android 适配、Node Android 宿主和打包脚本已逐文件阅读；补读生成运行时模块、Manifest、XML 资源及构建配置，路径和 SHA-256 在 `ANDROID_REVIEW_COVERAGE.json`。
- 共享应用已扩读手势、两套墙面相机/裁剪、转场、播放桥、音效链、YTM/Spotify 流、本地库和 Worker 等关键链路。共享 App.tsx、localMusicService.ts 等大文件仍有局部阅读范围；没有将全项目 2279 文件索引写成全部逐行审完。
- 依赖包、SDK、编译产物、归档副本不重复当作自有源码精读；已有 APK 仅做 ZIP 条目与归档哈希检查。
- 本轮未改实现，未运行测试、构建或上传；禁止删除或降级动画特效的约束继续有效。所有闪屏、卡顿和功耗改善均尚无修复后实机结论。

## PERF-43 — 自动播放先启动媒体、后切换 Web Audio 输出路径

- 证据：usePlaybackAudioBridge 自动播放先 audio.play()，成功回调才 setupAudioAnalyzer；App 的 onPlaying 也可能触发初次建图。createMediaElementSource 会把已在输出的媒体重定向到新图。
- 风险：初次自动播放时切换输出路径、增益和效果可能产生瞬态不连续；它不能解释所有持续播放中的杂音，也尚不能确诊用户短暂电流声。
- 实施：自动播放调用 play 之前先完成建图和输出增益设置，先请求恢复 context；保留媒体的 autoplay 权限语义和全部效果，不在 play 成功后再初次重接图。

### PERF-11 回退路径边界补充

进一步核对 uiYield.ts / trackProfile.ts / beatThis.ts：既有主线程回退已经按 8ms 预算让出 UI，本轮不重复实现已有分片；移除永久拒绝 Worker 的状态仍有意义，但不能把回退描述成整曲不让出的单个长任务。实时帧影响仍需按实际长任务定位。

## PERF-44 — 播放状态快照重复调用前台通知且未限制重复提醒

- 证据：FoliaPlaybackService.onStartCommand 每次调用两次 startForeground；Notification 没有 only-alert-once 标记，原生每 10 秒同步一次进度。
- 风险：多余系统 IPC/通知重建；若设备保留了有提示音的旧/用户自定义通知渠道，更新可能反复提醒。尚不能据此认定用户短暂电流声来自通知。
- 实施：每次状态更新只提升前台一次，最终元数据用 notify 更新；媒体通知只允许首次提醒，保留锁屏操作与前台服务语义。

## PERF-45 — 墙面重新进入裁剪范围的已入场磁贴再次从透明开始

- 证据：LatticePoster 每次挂载、且不在开场波次时使用 opacity:0 / scale:.94；PosterWall 裁剪直接卸载实例，没有保存该实例是否已完成入场。往返拖动、缩放重新纳入同一实例时，会重复完整淡入。
- 风险：已看过的图块在一次往返手势中重复变透明，可表现为图块闪动；这与 GPU 丢块不是同一证据，不能解释所有整屏闪动。
- 方案：按墙会话保存有限的已完成入场记录，重新纳入同一条目/实例时保持已完成相位；新条目仍播放全部原入场，交接翻牌仍由其独立时间线控制。

## PERF-46 — 启动遮罩早于实际页面内容和原生可绘制帧释放

- 证据：AppSplashGate 的挂载 effect 直接 hideAppSplash；lazy 首页/舞台和 ResizeObserver 后续才能补齐，未与 WebView visual-state fence 关联。
- 方案：Android 主页面提供实际 surface-ready 信号；冷启动与返回同样等可见内容准备和原生视觉状态，随后播放现有淡出。OBS/远程页保留自身启动路径，不能强加依赖造成死锁。
- 限制：这是可定位的过早释放，仍不能据此确诊全部空闲整屏闪动。

## PERF-47 — 裁剪预算优先级泄漏到图块呈现顺序

- 证据：collectShapeSlots 先返回 viewport 交集，再返回其余 overscan；调用方直接用这个数组渲染。随着可见分类变化，同一保留节点的 key 虽不变，React 仍需移动 DOM，稳定 key 不能防止重排。
- 方案：仅在选择有限集合时应用可见优先；最终按 row/column/slotIndex 固定世界地址呈现。保留全部图块视觉/交互/动画，不扩大预算或取消效果。
- 验证：不同视口采样间共同 key 相对顺序必须相同，且原可见区优先预算不变；是否消除手机封面闪仍待实机。

## STARTUP-01 — 启动失败异常的 message 为空时丢失诊断

- 用户 2026-10-31 截图为 Android backend startup failed: null。Plugin.start 原来只拼 getMessage；类型、原因链、阶段均丢失。截图尚不能确诊根因。
- 实施：安装清理、两次归档解压、前端安装、Keystore、CA、进程启动和 ready 握手分别标记；无 message 时保留异常类名，保留原因链且避免循环，原生 Log.e 记录异常；不重置用户密钥或账户。

## STARTUP-02 — 更新解压前不释放旧运行时，且遗漏失败目录

- 原实现解压后才清理旧 .ready 目录，失败目录永远不清理；每版 Node/native 解压约 510 MiB，前端另计。全路径排序删除还增加峰值内存。
- 实施：未启动进程、类锁保护下先清理符合精确安装目录命名的旧版本；包括未写 ready 的半成品，不匹配 runtime-data/runtime-key；walkFileTree 默认不跟随链接，流式删除。失败解压清理自身，ready 创建失败不继续。
- 必要检查：纯 JVM 使用真实文件/只读库/外部与断裂符号链接/重复清理，确认用户数据不变；无 message 的 crypto/null cause 和循环原因链正确描述。Android 编译与发布检查另见 WORKLOG。并非用户手机启动已通过的证据。
