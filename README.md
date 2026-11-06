# 拼豆图纸智能识别与校对 APP

一个完全离线的 Flutter 客户端项目，可识别图纸原有网格并生成对应行列的拼豆矩阵，使用 Lab + CIEDE2000 匹配 MARD 色卡，并支持逐格改色、色号高亮与本地 JSON 保存。

## 已实现

- 相册、相机、文件导入（JPG / JPEG / PNG / WEBP）
- 自动识别图纸网格行列，采样格子内部并排除网格线与空白背景
- 像素图、效果图保留逐格线，每 5 格和每 29 格加强定位线
- Lab + ΔE2000 色差匹配
- 原图、像素图、拼豆效果图三视图
- 颜色统计、豆数、尺寸与名称信息
- 单击格子查看行列与色号，选择 MARD 色号替换
- 单击颜色清单进入制作高亮模式
- 图纸 JSON 保存到系统文档目录
- 手机窄屏与 Windows 宽屏自适应布局
- MARD 291 色独立配置：`color_card/MRAD_color.json`

## 本地运行

项目需要 Flutter 3.27 或更高版本。

### 无 Flutter SDK 时的电脑界面预览

仓库包含一个仅用于视觉和交互验收的浏览器预览：`preview/index.html`。Windows 下双击项目根目录的 `启动电脑预览.cmd`，将自动启动本地静态服务并打开 `http://127.0.0.1:4174/preview/`。不要直接双击 `preview/index.html`，否则浏览器可能无法读取色卡。色卡成功加载后会缓存在本地，服务短暂中断时仍可继续识别。正式功能与打包仍以 Flutter 客户端为准。

```powershell
flutter pub get
flutter run -d windows
```

连接 Android 手机或启动模拟器后：

```powershell
flutter run -d android
```

## 打包

```powershell
flutter build apk --release
flutter build windows --release
```

Android APK 位于 `build/app/outputs/flutter-apk/app-release.apk`；Windows 产物位于 `build/windows/x64/runner/Release/`。

> 当前电脑环境未安装 Flutter SDK，因此本仓库生成时无法在本机执行编译。首次安装 Flutter 后，可运行 `flutter create --platforms=android,windows .` 补齐或刷新平台工具生成文件，再执行上述命令。该操作不会覆盖 `lib/`、`color_card/` 和 `pubspec.yaml` 中的业务实现。

## 数据来源

MARD 291 色 RGB 数据来自公开色卡仓库：<https://github.com/HansBug/pindou-color-data>。色值为屏幕参考值，实际制作前建议与手中的实体豆色卡核对。
=======
