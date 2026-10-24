# 轻截 QingCapture

<img src="docs/assets/icon.png" width="88" alt="QingCapture icon">

原生 macOS 截图、标注、滚动长截图与本机翻译工具。无第三方运行环境，使用 Swift / AppKit / ScreenCaptureKit / Vision / Apple Translation。

[English](README.en.md) · [下载](https://github.com/296777101-creator/QingCapture/releases) · [使用与开发](docs/DEVELOPMENT.md) · [架构](docs/ARCHITECTURE.md) · [隐私](docs/PRIVACY.md)

## 功能

- 区域截图、全屏选区、Retina 原始像素导出。
- 矩形/椭圆（空心、实心）、单双向箭头、直线、画笔、荧光笔、中文文字、序号、橡皮擦、马赛克及模糊。
- 直接选择颜色、线宽、字号及马赛克强度；撤销、重做、可撤销清空。
- **滚动长截图**：手动滚动原页面，自动识别重叠并拼接；支持暂停、继续、手动捕获、完成与取消。
- **文字识别与翻译**：本机 OCR，编辑原文，选择目标语言，复制译文。
- 贴图置顶、PNG 保存、PNG/TIFF 剪贴板复制。
- 可录制、保存、恢复默认的全局快捷键，支持冲突提示；单实例运行。

## 安装与权限

运行要求：macOS 14+；翻译需要 macOS 15+。当前预编译下载包为 Apple Silicon (`arm64`)，Intel 用户可从源码编译。

1. 从 [Releases](https://github.com/296777101-creator/QingCapture/releases) 下载并解压。
2. 将「轻截.app」放入“应用程序”，然后打开。
3. 在“系统设置 → 隐私与安全性 → 屏幕与系统音频录制”允许轻截。系统要求时重新打开应用。

预编译包采用本机 ad-hoc 签名，未经过 Apple Developer ID 公证；macOS 可能要求你在系统设置中自行确认是否打开。也可以使用下面的源码构建方式。

关闭启动窗口后，轻截仍在顶部菜单栏运行。默认快捷键 **Control + Option + A**；已有配置会保留，可在「快捷键设置…」自行录入并保存。

## 日常截图

按快捷键 → 拖框选区 → 选择工具标注 → **Enter** 复制，或 **Command + S** 保存。**Esc / 右键** 取消。

文字 **Enter** 确认、**Shift + Enter** 换行；**Command + Z** 撤销，**Shift + Command + Z** 重做。方向键微调选区，按住 Shift 每次移动 10 点。工具按钮有中文名称和悬浮提示。

## 滚动长截图

1. 先框选要截取的页面内容，点击工具栏 **长截图**（或按 S）。
2. 在绿色边框内的原应用里慢慢向下滚动。建议每次不超过选区高度的一半，保留重合内容。
3. 浮动面板显示已拼接的段数和图片尺寸；可暂停或点击“捕获一段”。
4. 点击 **完成长截图**，在可滚动的长图编辑窗口继续标注、复制、保存或识别文字。

重复、反向或无法可靠对齐的画面不会直接接入。若提示“暂未对齐”，请慢些滚动或稍向上回滚。动态视频、完全相同的重复列表、视差页面与横向滚动可能无法对齐。默认上限为 3,200 万像素和 30,000 像素高度；暂不支持跨显示器拼接。

## 翻译

在截图工具栏点击 **翻译**（或按 G），或在 OCR 结果窗口点击“翻译文字”。可以修改原文，选择原文/目标语言，点击“开始翻译”并复制结果。

翻译使用 macOS 自带的 Apple Translation。首次使用某个语言组合时，系统可能提示下载语言包，需要联网完成下载；模型准备好后在本机处理。没有第三方翻译 API、密钥或截图上传。具体系统数据处理见 [隐私说明](docs/PRIVACY.md)。

## 从源码构建

安装 Xcode 或匹配的 Command Line Tools（含 macOS 15+ SDK），然后运行：

```bash
git clone https://github.com/296777101-creator/QingCapture.git
cd QingCapture
bash scripts/test.sh
bash scripts/build.sh
open build/Artifacts.noindex/轻截.app
```

本机安装和创建桌面入口：`bash scripts/install.sh`。生成下载 ZIP：`bash scripts/package.sh`。

脚本自动选择兼容 SDK 和当前 CPU；可使用 `QINGCAPTURE_SDK_PATH`、`QINGCAPTURE_ARCH=arm64` 或 `QINGCAPTURE_ARCH=x86_64` 覆盖。所有源码、测试、构建与安装脚本均已提供。

## 文档与参与

[更新记录](CHANGELOG.md) · [开发指南](docs/DEVELOPMENT.md) · [贡献指南](CONTRIBUTING.md) · [安全](SECURITY.md) · [MIT 许可证](LICENSE)

本项目为独立截图工具，不隶属于微信或 Apple。界面与交互参考常见截图工具，未使用其私有实现或素材。
