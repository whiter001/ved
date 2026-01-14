<h1 align="center">Ved</h1>
<h3 align="center">一个用 V 编写的轻量级快速文本编辑器</h3>

<img src="https://user-images.githubusercontent.com/47652746/199333211-ee78f600-039c-4d96-85ec-e5580fca6736.jpg" alt="编辑器截图">

[![Patreon-badge](https://img.shields.io/badge/Patreon-F96854?logo=patreon&logoColor=white)](https://www.patreon.com/vlang)
![GitHub Workflow Status (event)](https://img.shields.io/github/actions/workflow/status/vlang/ved/ci.yml?branch=master)

### 这是预 alpha 软件。

自 2017 年 6 月以来，我一直在使用 Ved 作为我的主要编辑器（2018 年 6 月用 V 重写）。

它可能不适合所有人。目前存在一些必须解决的限制。
我们正在逐步改进 Ved 的稳定性和用户体验。

要配置编辑器，请参阅[配置](#configuration)部分。

### 从源码构建

在 Linux 上，您需要[安装一些包](https://github.com/vlang/v?tab=readme-ov-file#testing-and-running-the-examples)，
以使用 X11 库，因为 Ved 是一个图形应用程序。在 macOS 和 Windows 上，可以跳过此步骤。
然后[安装 V](https://github.com/vlang/v#installing-v---from-source-preferred-method) 并编译 ved。

#### 使用 build.sh（推荐）

您可以使用提供的构建脚本进行快速简单设置：

```bash
chmod +x build.sh
./build.sh
./ved
```

脚本支持其他选项：
- `./build.sh --prod`：以生产模式构建（优化）。
- `./build.sh --freetype`：使用 Freetype 支持构建。

#### 手动构建

或者，您可以使用 V 编译器手动构建：

```bash
v -o ved .
./ved
```

Ved 应该在不到一秒内构建完成。

默认情况下使用 V 的内置字体渲染，但有一个选项使用 freetype，
这可能为某些用户提供更好的渲染：

```bash
v -d use_freetype -o ved .
```

要使用 freetype，必须先在您的系统上安装它。
按照以下步骤针对您的平台操作。

Ubuntu：
```
sudo apt install libfreetype6-dev libx11-dev libxrandr-dev mesa-common-dev libxi-dev libxcursor-dev
```

Fedora：
```
sudo dnf install freetype-devel libXcursor-devel libXi-devel
```

Arch：
```
pacman -S freetype2
```

macOS：
```
brew install freetype
```

Windows：
```
v setup-freetype
```

### 社区：

Discord（主要社区）：https://discord.gg/vlang。加入 `#ved` 频道。

### 主要功能

- 小尺寸（~ 1 MB 二进制文件，构建时间 <1s）
- 硬件加速文本渲染
- 高性能（滚动浏览 300k 行并带有语法高亮而无任何延迟）
- 正在开发的 Vim 模式
- 轻松集成任何编译器/构建系统
- 转到定义
- 模糊文件查找器
- 快速搜索
- 与 git 集成
- 内置时间管理系统（基于番茄工作法）
- 全局前置键
- 分屏视图
- 工作区
- 跨平台（Windows、macOS、GNU/Linux）

### 计划功能

- 真正的 vim 模式（当前实现仅实现了 vim 功能的一小部分）
- Emacs 键绑定
- Nano 键绑定
- 自动换行
- 更好的语法高亮

### 配置

Ved 在 `$HOME/.ved` 中创建一个设置目录，用于存储工作区、
会话、任务和配置文件。
配置文件是一个简单的 [TOML](https://toml.io/) 文件，名为 `conf.toml`。
它提供了一种更改一些基本设置和编辑器颜色的方法。

如果您不想触碰配置文件，您永远不必这样做！
Ved 不会自己创建它，并提供合理的默认设置来让您开始。
如果您更喜欢冒险，这里是一个包含所有可能设置的示例配置文件：

```toml
# 要开始，请在 $HOME/.ved 中创建一个名为 "conf.toml" 的文件
# 大多数设置都包含在这个 "editor" 表中。
[editor]
dark_mode = false       # Ved 内置了明亮和黑暗模式。
cursor = 'variable'     # Ved 有三种变体：Variable、block 和 beam。您可能习惯于 "variable" 或 "beam"。
text_size = 18          # ┌───────────────────────────────────────────────────┐
line_height = 20        # │ 这些 *可以* 被编辑，但您可能不应该这样做 │
char_width = 8          # └───────────────────────────────────────────────────┘
tab_size = 4            # Ved 使用制表符 (\t)。此设置更改制表符应显示为多少个空格
backspace_go_up = true  # 如果设置为 true，当您到达行首时，按退格键不会执行任何操作

# 如果您不喜欢 ved 的默认配色方案，或者您只是想要
# 一些新的东西，请编辑 "colors" 表。Ved 使用一种 base16 形式
# 来控制语法和编辑器高亮。请注意，由于 ved 的非常简化的高亮，
# 从互联网上复制的 base16 主题不会看起来像它们的截图那样。
[colors]
base00 = "efecf4"
base01 = "e2dfe7"
base02 = "8b8792"
base03 = "7e7887"
base04 = "655f6d"
base05 = "585260"
base06 = "26232a"
base07 = "19171c"
base08 = "be4678"
base09 = "aa573c"
base0A = "a06e3b"
base0B = "2a9292"
base0C = "398bc6"
base0D = "576ddb"
base0E = "955ae7"
base0F = "bf40bf"
```

### 基本用法

Ved 最适合与工作区（包含代码的目录）一起使用。
您可以有多个工作区，并使用 `C [` 和 `C ]` 在它们之间快速切换。

要打开多个工作区，请运行

`ved path/to/project1 path/to/project2`

键绑定：

`C` 在 macOS 上是 `⌘`，在所有其他系统上是 `Ctrl`。

```
C q q  退出编辑器
C o    打开文件
C s    保存
C r    重新加载当前文件
C p    打开 ctrlp（模糊搜索）
/      在当前文件中搜索
C g    将当前文件的路径复制到剪贴板
t      转到上一个文件
gd     转到定义

C c    git commit -am
C -    git diff
?      git grep（在当前工作区的所有文件中搜索）

C u    构建当前项目（构建指令必须位于 "build" 中）
C y    当前项目的替代构建（构建指令必须位于 "build2" 中）
C 1    从任何其他应用程序切换到 Ved（目前仅在 macOS 上）

C d    转到上一个分屏
C e    转到下一个分屏
C [    转到上一个工作区
C ]    转到下一个工作区

C a    开始新任务
C t    显示计时器/番茄工作法窗口


```

支持的 vim 绑定：
```
j k h l         下、上、左、右（移动光标）
0 $ ^           转到行的绝对开始、结束和第一个非空白字符
C-F C-B         向下翻页、向上翻页
L H             转到页面的顶部/底部
w b             下一个/上一个单词
dw de cw ce     删除单词
di ci           智能删除
A I             转到行首/行尾，插入模式
o O             在下方/上方新建行，插入模式
v               选择模式
zz              居中当前行
y d p J         复制、删除、粘贴、连接行
.               重复上一个操作
< >             向右/左缩进
/ * n           搜索、在光标下单词中搜索、下一次出现
gg G            转到文件的开始/结束
x r             删除/替换光标下的字符
C-n             自动补全
+y              复制并粘贴到系统剪贴板
```

