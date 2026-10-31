# Project Skills

本仓库的项目规则按 skill 组织。这里放整个项目统一的开发规范和 skill 索引，细节在各 skill 里。

使用方式：

1. 如果需要的话，先根据任务选择最相关的 skill。
2. 读取对应 `skills/<skill-name>/SKILL.md`。
3. 按 skill 中的触发条件和执行规则完成工作。
4. 如果多个 skill 同时相关，可以组合使用，但只加载当前任务真正需要的内容。不需要 skill 的任务不要读它们。

## 开发规范

### 目录

- **一个功能的代码放在一起。** 先按功能分，再按代码种类（界面、状态、数据读取）分：一个功能的文件放进它自己的一处，它之外只留几个接入点。删掉那一处和那几个接入点，功能就删干净了。例子：`src/components/login/`、`src/components/app/home/explore/`。
- 先平铺，目录难以一眼看完（大约 15 个文件以上）才加子目录，不提前建空目录。
- 只服务一个变体（一个平台、一种后端、一种设备）的代码放在那个变体那里，两个功能都用到才挪去共用的地方。平台的目录名就是 `src/services/onlineMusic/providerRegistry.ts` 里登记的 id：`src/services/onlineMusic/<id>/`、主进程的 `electron/<id>/`。
- 语言或工具按路径找到的文件（测试的收集范围、`import.meta.glob`、检查脚本扫的目录）留在原处。
- 新加的代码和正在整理的模块按这几条放，不这样放要写明原因；没人在动的旧代码留在原处，怎么挪见 `file-modularization`。
- 入口文件只做组装。`src/App.tsx` 已经远超大小警戒值，新行为放进相邻的 `components/app/*`、hooks、stores、services。各类文件的大小警戒值和挪文件的做法见 `file-modularization`。

### 模块边界

- **依赖方向**：`stores`、`utils`、`types`、`services` 不在运行时依赖 `components`；`utils` 也不依赖 `hooks`、`stores`；`types` 不依赖任何实现；`components`、`hooks`、`stores` 不直接用平台的 `*Provider.ts`、`*Transport.ts`。检查规则是 `dev/mcp/ts-code-map/codemap.mjs` 的 `BOUNDARY_RULES`，现有的违规列在 `docs/CODEMAP.md` 的“分层边界违规”，不再加新的。
- **在线歌曲只走 omni。** 搜索、播放、歌词、歌单、账户都调 `src/services/onlineMusic/omni.ts`；只有各平台的 `<id>Provider.ts` 和 `<id>Transport.ts` 碰平台的原始接口（网易云没有 Transport，请求在 `src/services/onlineMusic/netease/netease.ts`）。omni 缺一项能力时，在 `src/types/onlineMusic.ts` 和 `omni.ts` 加上，再在各平台实现，不另开旁路。细则见 `online-song-omni-routing`。
- **一个平台的规则留在那个平台的目录里。** 只是看着像的不要合并成共用规则。平台目录外每个文件提到平台名的次数记在 `test/unit/onlineMusic/platformNamePlaces.ts`，`test/unit/onlineMusic/omniArchitecture.test.ts` 核对它。
- **加一个同类的东西只动它自己的目录和注册点**：歌词样式和背景放各自的 `entry.tsx`，由 registry 自动发现；平台在 `providerRegistry.ts` 登记；命令放 `src/components/command-palette/commands/`，一组命令一个 `<组>Commands.ts`，自带界面的单条命令一个 `*Command.ts`，都用 `commandFactories.ts` 里的函数建，切换歌词样式的命令写在那个样式的 `entry.tsx` 里。不在 `App.tsx` 里加分支。衡量一个模块看“再加一个平台、一个歌词样式、一种模组要改哪些地方”。
- **渲染进程只经 `electron/preload.cjs` 暴露的接口找主进程。** 窗口都开 `contextIsolation`、关 `nodeIntegration`。

### 命名

- 组件文件大写开头（`PlayerPanel.tsx`），其他文件小驼峰（`latticeModel.ts`），文件名不用连字符。按路径找到的固定名字照旧：`entry.tsx`、`tuning.ts`、`*.surface.tsx`。
- hook 以 `use` 开头。zustand store 叫 `use…Store`：几处共用的放 `src/stores/`，只给一个功能用的放在那个功能的目录里（如 `src/components/login/loginWindowStore.ts`）。
- 日志行首写 `[模块名]`，见下面的“日志”。

### 类型和代码格式

- 几个功能之间共用的类型（契约）放 `src/types.ts`（全局设置）和 `src/types/`（如 `onlineMusic.ts`）；只给一个功能用的类型放在那个功能的目录里。
- TypeScript 开着 `strict`；类型检查跑 `npm run typecheck`。
- 仓库没有自动格式化工具：4 个空格缩进、单引号；文件用 LF 换行、末尾留一个换行（这两条写在 `.editorconfig`）。

### 注释

不要主动移除项目中的注释，也不要在没有明确指令的情况下修改、删除或翻译 `@note` 注释。新建文件时，在导入行结束后写一行注释说明这个文件；复杂的函数写一句注释说明它做什么。

### 界面

- 用项目自己的控件：设置页用 `src/components/modal/settings/kit/`（`Select`、`Slider`、`Toggle` 等），别处的下拉框用 `src/components/shared/CustomSelect.tsx`，不用系统自带的 `<select>`。图标只用 `lucide-react`。弹窗、文字测量等现成工具见 `reuse-project-utilities`。
- 样式用 Tailwind；只属于一个功能的 CSS 文件放在那个功能的目录里（如 `src/components/app/lattice/Lattice.css`）。
- 界面上的文字都走 i18n（`t()`），三份语言文件 `src/i18n/locales/en.ts`、`zh-CN.ts`、`in.ts` 一起加。繁体中文不用写：构建时由 `dev/i18n/traditionalLocalePlugin.mjs` 从 zh-CN 转出来。主进程（`electron/*.cjs`）自己的文案表也有 zh-TW，要手写成 zh-CN 的转换结果，`test/unit/i18n/traditionalMainProcessText.test.ts` 会核对。
- 新设置：外观类的进配置导入导出（`src/components/modal/settings/pages/storage/visualConfigTransfer.ts`、`src/utils/appearanceCodec.ts`）；功能类的设置和可执行动作进命令面板。细则见 `settings-feature-integration`。

### 存下来的数据

- 设置值放在 `src/stores/` 对应领域的 `use*SettingsStore` 里，组件里不另起一套 localStorage 读写。新写的读写用 `src/stores/storagePrimitives.ts`；一些旧文件还直接调 localStorage。
- 已经发布的存储键不改名。`src/stores/` 和各样式 `tuning.ts` 里的键由 `test/unit/stores/storeContract.test.ts` 记着快照；别处的键没有测试钉住，同样不改名。

### 日志

项目内置了开发者日志系统，需要打日志时直接用它，不要另造：`console.log` / `info` / `warn` / `error`，行首写 `[模块名]`。
渲染进程和主进程的行都在应用内“设置 → 开发者”的面板里可见（“运行日志”开关）；再打开其下的“写入本地文件”，还会写入 `logs/runtime/`。
写法与取舍（成功也要记，记决定而不是记经过）见 `docs/client-logging.md`。
日志里直接交抛出的错本身（`console.warn('[模块] ...', error)`），不要只交它的 message：会话日志和 DevTools 靠它记下调用栈，排查要的是完整的原文。要把错放进一个对象或者拆成一句话时，用 `src/utils/errorText.ts` 的 `errorFields` / `errorMessage`。凭据（cookie、token、密码）的值不写进日志行。

### 测试放哪

- 逻辑的单元测试放 `test/unit/<区域>/*.test.ts`，用 Vitest 跑：`npm run test:unit`。
- 只有真浏览器里才看得到的问题放 `test/component/*.spec.ts`（`npm run test:component`）；整页的界面测试在 `test/ui/`；`npm run test:ui` 两种都跑。手动跑的脚本在 `test/manual/`。
- `src/` 里不放测试。该跑哪一种、什么时候不要跑构建，见 `testing-strategy`。

### 生成的文件不手改

文件头写着由哪个 `npm run` 脚本生成的（`docs/CODEMAP.md`、`mods/folium.d.ts`、`docs/folium/api.md`），改它的源头，再跑那个脚本。`api/qq.js` 由 `npm run build:vercel-api` 从 `api-ts/qq.ts` 编出来。

### 依赖

音乐平台用的库钉死版本，不写 `^` 或 `~`：我们会替换或直接读其中一些库的内部文件，小版本变了也可能坏。每个平台用哪个库、版本钉在哪几处、上游变了怎么跟，见 `src/services/onlineMusic/UPSTREAMS.md`。

## 代码定位

按成本从低到高三层：先读 `docs/CODEMAP.md`（`npm run codemap` 从编译器和模块图生成，main 落地后由 `codemap-sync` workflow 重新生成，不会过期）；符号级问题默认用 rg；rg 拿不准时才用 `dev/mcp/ts-code-map/cli.mjs`。什么时候该升级见 `codebase-navigation`。

## 当前项目内 skills

- `codebase-navigation`：代码定位的三层顺序，定位之后改动要守的依赖方向，以及几个已经不存在、但仍会被搜到的旧名字。
- `file-modularization`：新代码放在哪里（一个功能的代码放在一起）、什么时候加子目录、哪些文件不能挪、怎么挪，以及入口文件和 `App.tsx` 的大小警戒值。
- `testing-strategy`：什么时候写新测试，以及该看热加载报错、跑单测、跑 UI 截图测试，还是不要误跑构建。
- `readme-reference`：改代码、测试、流程或文档前，从仓库内 README 中取仍然有效的上下文，并核对它。
- `glossary-alignment`：把口头说的组件、视图、状态、面板、模式等说法换成可检索的符号名或模块名。
- `frontend-runtime-guardrails`：高频动画、`useMotionValueEvent`、`requestAnimationFrame`、`ResizeObserver` 和 React state 更新频率的约束，避免 visualizer 等路径引入高 CPU 或时序错位。
- `reuse-project-utilities`：先复用仓库已有的工具和库（pretext 文本测量、visualizer runtime、歌词时序 helper、字体和颜色 helper、i18n、lucide 图标、虚拟列表、弹窗），不要重复造轮子。
- `settings-feature-integration`：新增或调整设置项时的接入位置：视觉设置进外观配置的导入导出，功能性设置和可执行动作进命令面板。
- `online-song-omni-routing`：在线歌曲的搜索、播放、歌词、歌单、账户和跨平台数据流都经过 Omni，只有平台的 adapter 和 transport 直接接触原始接口。
- `kugou-provider-alignment`：开发时按 `docs/ku-go-api-docs.md`、`.env.local` 中的真实酷狗服务和 `.dev-credentials/kugou.json` 对齐酷狗 provider 的请求与响应，不猜接口结构。
- `prepare-folia-release`：稳定版本发布流程：汇总上个稳定版本以来用的人能感到的变化，更新新功能介绍、桌面与 Docker 版本号，并生成可手动粘贴的 Markdown release note。
- `run-desktop`：启动并驱动 Electron 桌面版（隔离的 profile，后台驱动加单条命令的客户端：截图、点击、填表、在页面和主进程里求值、读日志），在真的桌面构建里验证主进程、preload IPC 和桌面专属设置的改动。

四份开发者指南：

- 接入一个新的在线平台：`src/services/onlineMusic/README.md` 的“接入一个新平台”。
- 平台接入探索页：`src/services/onlineMusic/EXPLORE_ADAPTER.md`。
- 各平台依赖的上游、版本钉在哪、上游变了怎么跟：`src/services/onlineMusic/UPSTREAMS.md`。
- 加一个歌词动画样式：`src/components/visualizer/README.md` 的“加一个歌词动画样式”。

## 全局沟通规则

- 回答用户问题时，直接给出结论，不添加无关的辅助性评价措辞。
- 如果用户指出的是潜在 bug 或不合理设计，需要直接指出问题并给出建议，不回避。

## Android 工作连续性（用户要求）

- 继续 Android 适配前先读根目录 `WORKLOG.md`，以最新用户反馈和未完成项为准；修改、验证、交付后及时更新。
- `WORKLOG.md` 分别记录用户实机反馈、代码改动、实际执行的检查和剩余问题。编译成功、签名通过、上传成功均不能写成实机修复通过。
- 用户要求减少不必要的测试，手机效果由用户测试。交付前完成必要的类型检查、APK 发布构建和签名检查；不自行扩展为模拟器或全套 UI 测试。
- 不重新引入已导致实机退化的方案：把同一个 WebView 每帧画入第二个硬件画布、软件截图冒充实时玻璃、移动中反复切换整墙的 `will-change: transform`。
- 原生玻璃不可用时明确说明当前降级，不把网页背景模糊描述为已完成 Kyant 原生折射。对闪烁和功耗的结论以实机证据为准。
- 当前交付渠道为用户授权的 GitHub 仓库与 Release，优先上传 APK 并给出链接，随后同步对应源码；不恢复使用 Catbox。不得提交签名密钥、登录凭据、本机配置或缓存。

## Android 当前通过基线（2026-10-31）

- 用户确认 mobile.14 能启动，滑动/缩放不闪；此前音频/返回也通过。保护密钥恢复、有限磁贴物化、固定世界顺序、真实首帧交接；不得为了“恢复动画”重新让保留节点移动或重播已完成入场。
- 当前工作扩展到前端、Node、原生的功耗；优先减少重复计算/布局/桥复制/无消费者驱动，适合的 IO 用原生后台执行器。不通过删特效、限低帧率、降画质或换静态截图完成节能。
- 设置入场与新玻璃/悬浮入口的实机状态单独记录；没有手机量测就不写瓦数降幅。读取覆盖范围和原生替换未完成项仍见 WORKLOG / PERFORMANCE_REVIEW / REPAIR_STATUS。

- mobile.16 原生光学为 Kyant AGSL 源码移植，Android 13+ 使用 RuntimeShader/RenderEffect 对单次 WebView 输出的有限玻璃边缘折射/色散；不是 Compose 控件或独立 DOM 背景层。禁止重新引入双绘制，旧 Android 回退与未测功耗须如实说明。

- mobile.17 用户反馈为“骁龙 8 Gen 2、未充电、莫奈及其他页面约 10W”。功耗日志的电池数值是整机瞬时估算，宿主 CPU 不含隔离 renderer/GPU；不得混淆口径。原生替换剩余边界见 docs/android/POWER_REWRITE.md。
