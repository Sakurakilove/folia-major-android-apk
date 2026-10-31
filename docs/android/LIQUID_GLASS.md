# Android 液态玻璃集成

mobile.16 使用 Kyant0/AndroidLiquidGlass 的原生 AGSL 核心，来源提交 `65ab177e90e5c1d8c62e70cf7755841982da65f6`，Apache-2.0 许可证及修改说明随 APK 分发。源码位于 `android/app/src/main/assets/shaders/kyantGlass.agsl`；原生宿主为 `FoliaLiquidGlass.java`，DOM 几何发布为 `installAndroidGlass.ts`。

渲染路径：WebView 单次原生输出 → Android RenderEffect / RuntimeShader → 当前窗口。没有 Canvas/Bitmap/PixelCopy 捕获，也不再次调用 WebView.draw。

移植内容包含圆角矩形 SDF/梯度法线、circleMap 折射、深度法线与七色分解采样、方向性高光。与 Compose API 的区别：多个 DOM 表面由矩形 uniform 描述；取样向边缘外侧以避免把当前 DOM 前景拉入折射，所有色散取样钳制视口。矩形内部和外部保持输入像素，只有边缘参与光学。材质中部依然用网页 tint/backdrop，不能把此实现描述成 Compose 原样套用或分离了全部 DOM 前景/背景。

几何只有布局/transform/opacity 变化才提交，原生按 Choreographer 合并；同值去重、single-flight，最多 8 个表面，优先前景。相机/歌词内容的动画由原生输入直接取样，不每帧跨 JS 桥搬像素。没有独立永久 Choreographer/JS 轮询，仍有原生整视口效果缓冲成本，实际功耗须手机测量。

Android 13+ 才启用原生 RuntimeShader；Android 8–12 保留材质回退。低版本不具备原生色散，不能声称完整光学支持。

必要算法核对用 `test/manual/android/checkKyantOptics.py`（宿主可选 skia-python，不是应用依赖）。记录的宿主 240×160 采样中 2900 个边缘像素改变、色散开关对照 1193 个像素不同，内部/外部逐字节不变；这不代替手机 GPU 效果与性能验证。

mobile.17 将外包围、半尺寸、折射高度和梯度半径移到 Java 几何更新时计算，新增无效区域/安全内部快路径，并把 style 观察限定到玻璃和祖先。宿主多区域对照需保持 mobile.16 原像素；整视口 RenderEffect 输入仍在，不能把 shader 跳过运算写成已经局部化全部 GPU 缓冲。
