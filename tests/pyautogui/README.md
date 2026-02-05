# Ved PyAutoGUI Testing

This directory contains UI automation tests for Ved using [PyAutoGUI](https://pyautogui.readthedocs.io/).

## Prerequisites

1.  **Python 3.10+**
2.  **Dependencies**:
    ```bash
    pip3 install pyautogui opencv-python
    ```
3.  **Permissions (macOS)**:
    Ensure your Terminal/IDE has "Accessibility" and "Screen Recording" permissions in System Settings -> Privacy & Security.

## Running Tests

To build and run the basic test (creates a temp file and verifies its contents):
```bash
python3 ved_test.py --build
```

Run with a specific file path and keep the app open:
```bash
python3 ved_test.py --file ./out/smoke.txt --no-close
```

## How it works

Unlike AskUI, PyAutoGUI runs entirely locally:
- `pyautogui.write()`: Simulates keyboard input.
- `pyautogui.hotkey()`: Simulates modifier keys (Cmd/Ctrl).
- `pyautogui.locateOnScreen()`: (Optional) Can be used to verify UI state by matching image snippets.
- The test writes to a real file, saves it, and then verifies the file contents on disk.
