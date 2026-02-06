# Ved PyAutoGUI 测试

此目录包含使用 [PyAutoGUI](https://pyautogui.readthedocs.io/) 的 Ved UI 自动化测试。

## 先决条件

1.  **Python 3.10+**
2.  **依赖项**：
    ```bash
    pip3 install pyautogui opencv-python
    ```
3.  **权限 (macOS)**：
    确保您的终端/IDE 在系统设置 -> 隐私与安全中具有“辅助功能”和“屏幕录制”权限。

## 运行测试

要构建并运行所有测试：
```bash
python3 ved_test.py --build
```

### 提升效率的方案

1.  **列出所有可用测试**：
    ```bash
    python3 ved_test.py --list
    ```

2.  **定向测试 (运行特定测试)**：
    ```bash
    python3 ved_test.py --names test_word_movement test_undo
    ```

3.  **只运行上次失败的测试**：
    ```bash
    python3 ved_test.py --failed
    ```

4.  **跳过已通过的测试 (缓存成功项)**：
    ```bash
    python3 ved_test.py --skip-passed
    ```

## 工作原理

与 AskUI 不同，PyAutoGUI 完全在本地运行：
- `pyautogui.write()`：模拟键盘输入。
- `pyautogui.hotkey()`：模拟修饰键 (Cmd/Ctrl)。
- `pyautogui.locateOnScreen()`：（可选）可用于通过匹配图像片段来验证 UI 状态。
- 测试会写入真实文件，保存它，然后在磁盘上验证文件内容。
