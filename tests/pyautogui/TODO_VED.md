# VED 开发与测试跟踪 (TODO)

这个文档用于跟踪 `ved` 编辑器的功能优化及 `pyautogui` 自动化测试的进展。

## 🚀 已完成任务 (Completed)

- [x] **退出逻辑优化**：只需按一次 `Ctrl + Q` 即可退出编辑器（原先需要按两次）。
- [x] **Ctrl + P 交互优化**：
    - [x] 修复了进入 `Ctrl + P` 模式时默认会填入一个字符 `p` 的问题。
    - [x] 在查询模式（`Ctrl + P`、搜索等）下支持使用 `Backspace` 和 `Delete` 键删除字符。
- [x] **自动化测试更新**：
    - [x] 同步更新 Python 测试脚本，将退出逻辑改为单次按键。
    - [x] 在 `test_fuzzy_finder` 测试中增加了退格删除并重新输入的验证逻辑。
    - [x] **测试效率提升方案**：
        - [x] 实现定向测试 (`--names`)。
        - [x] 实现失败项重试 (`--failed`)。
        - [x] 实现成功项缓存/跳过 (`--skip-passed`)。
        - [x] 添加测试列表显示 (`--list`)。

## 🛠️ 进行中 / 待处理任务 (In Progress / Pending)

### 功能优化
- [ ] **Ctrl + P 输入增强**：
    - [ ] 验证删除字符后，下方文件列表是否能实时、流畅地重新过滤。
    - [ ] 考虑在查询为空时显示最近打开的文件（MRU 列表）。
- [ ] **多平台支持**：进一步测试 `Ctrl + Q` 在不同系统（macOS/Linux/Windows）下的按键兼容性。

### 自动化测试增强 (`tests/pyautogui/ved_test.py`)
- [ ] **严格的内容验证**：
    - [ ] 在 `test_fuzzy_finder` 中增加逻辑，验证执行搜索并回车后，是否真的切换到了目标文件。
- [ ] **稳定性提升**：
    - [ ] 减少 `time.sleep` 的使用，改为基于文件状态或进程输出的动态等待。
    - [ ] 修复 `test_basic_editing` 在某些环境下保存延迟导致的失败问题。
- [ ] **新增功能测试**：
    - [ ] **可视模式测试**：
        - [ ] `test_visual_mode`: 测试 `v` (字符可视)、`V` (行可视)、`Ctrl+V` (块可视) 模式的选择和操作。
        - [ ] 验证选择后 `y` (复制)、`d` (删除)、`c` (更改) 等操作。
    - [ ] **高级导航与移动测试**：
        - [ ] `test_advanced_navigation`: 测试 `gd` (跳转到定义)、`[[` (跳转到函数开头)。
        - [ ] `test_z_center`: 测试 `zz` (当前行垂直居中)。
    - [ ] **工作区测试**：
        - [ ] `test_workspaces`: 测试 `Ctrl + [` 和 `Ctrl + ]` 切换工作区。
    - [ ] **编辑增强测试**：
        - [ ] `test_line_merging`: 测试 `J` (行合并)。
        - [ ] `test_indentation`: 测试 `>` (右缩进) 和 `<` (左缩进)。
        - [ ] `test_dot_repeat`: 测试 `.` (重复上一个动作)。
    - [ ] **搜索增强测试**：
        - [ ] `test_git_grep`: 测试 `Shift + /` (Git Grep)。
        - [ ] `test_search_in_folder`: 测试 `Ctrl + /` (在目录中搜索)。
    - [ ] **自动完成测试**：
        - [ ] `test_autocomplete`: 测试在插入模式下使用 `Tab` 进行补全。
    - [ ] **复制粘贴测试**：
        - [ ] `test_copy_paste`: 测试 `y` (复制行/选择)、`p`/`P` (粘贴) 功能。
        - [ ] 验证跨行和跨文件的复制粘贴。
    - [ ] **替换和编辑测试**：
        - [ ] `test_replace`: 测试 `r` (替换字符)、`cw` (更改单词) 等。
        - [ ] `test_line_operations`: 测试 `o`/`O` (新行插入)。
    - [ ] **移动和导航测试**：
        - [ ] `test_word_movement`: 测试 `w`/`b` (单词移动)、`e` (单词尾)、`$`/`0` (行首尾)。
        - [ ] `test_page_movement`: 测试 `Ctrl+F`/`Ctrl+B` (翻页)、`H`/`M`/`L` (屏幕位置)。
    - [ ] **分屏测试**：
        - [ ] `test_splits`: 测试 `Ctrl+D` (下一个分屏)、`Ctrl+E` (上一个分屏)、分屏切换。
    - [ ] **鼠标交互测试**：
        - [ ] `test_mouse_click`: 测试鼠标点击定位光标。
        - [ ] `test_mouse_drag`: 测试鼠标拖拽选择文本。
        - [ ] `test_horizontal_scroll`: 测试水平滚动功能（待验证是否已实现）。
        - [ ] `test_git_integration`: 测试 `Ctrl+G` (git diff)、`:wq` 等 git 相关功能。
    - [ ] **中文输入测试**：
        - [ ] `test_chinese_input`: 测试中文字符的输入和显示。
        - [ ] 验证 Unicode 字符的正确处理。

### 其它
- [ ] 依照 `TODO.txt` 继续完善鼠标“点击定位”和“拖拽选择”功能。
