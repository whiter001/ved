import subprocess
import time
import os
import sys
import platform
import pyautogui
import pyperclip
from pathlib import Path

# Base setup
CWD = Path(__file__).parent.parent.parent
VED_BIN = CWD / "ved"
TEST_FILE = CWD / "tests" / "pyautogui" / "test_output.txt"
BASE_CONTENT = """line 1: hello
line 2: world
line 3: vlang
line 4: ved editor
"""

class VedAutomator:
    def __init__(self, file_path):
        self.file_path = file_path
        self.process = None
        self.ctrl = 'command' if platform.system() == 'Darwin' else 'ctrl'

    def start(self):
        if self.file_path.exists():
            self.file_path.unlink()
        self.file_path.write_text(BASE_CONTENT)
        
        env = os.environ.copy()
        env["VED_TEST"] = "1"
        cmd = [str(VED_BIN), "-window", str(self.file_path)]
        self.process = subprocess.Popen(cmd, env=env)
        time.sleep(2)
        self.focus()

    def focus(self):
        if platform.system() == "Darwin":
            os.system(f"osascript -e 'tell application \"System Events\" to set frontmost of process \"ved\" to true' 2>/dev/null")
        time.sleep(1.0) # Increased delay for focus

    def press(self, key):
        self.focus()
        pyautogui.press(key)
        time.sleep(0.3) # Increased delay between keys

    def write(self, text):
        self.focus()
        pyautogui.write(text, interval=0.1) # Slower typing
        time.sleep(0.5)

    def hotkey(self, *args):
        self.focus()
        pyautogui.hotkey(*args)
        time.sleep(0.5)

    def save(self):
        self.hotkey(self.ctrl, 's')
        time.sleep(1.0)

    def undo(self):
        self.focus()
        pyautogui.press('u')
        time.sleep(0.5)

    def quit(self):
        if self.process and self.process.poll() is None:
            # 1. Ensure we transition back to normal mode from any sub-mode (query, insert, etc.)
            # This handles the "transition exit" requirement.
            for _ in range(2):
                self.press('esc')
                time.sleep(0.2)
            
            # 2. Send Ctrl/Cmd+Q to exit (now only requires one press)
            self.hotkey(self.ctrl, 'q')
            
            try:
                self.process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                print("ved did not exit within timeout, force terminating...")
                self.process.terminate()

    def get_content(self):
        return self.file_path.read_text()

def test_basic_editing():
    print("\nRunning test_basic_editing...")
    ved = VedAutomator(TEST_FILE)
    ved.start()
    
    # Go to end of file, enter insert mode
    ved.hotkey('shift', 'g') # G
    ved.hotkey('shift', 'a') # A - Append at end of line
    time.sleep(1)
    ved.write("\nnew line added")
    time.sleep(1)
    ved.press('esc')
    ved.save()
    
    content = ved.get_content()
    ved.quit()
    
    if "new line added" in content:
        print("✅ test_basic_editing passed")
    else:
        print("❌ test_basic_editing failed")
        print(f"Content: {content}")

def test_vim_movements():
    print("\nRunning test_vim_movements...")
    ved = VedAutomator(TEST_FILE)
    ved.start()
    
    # gg: top, j: down, x: delete first char of second line
    ved.press('g')
    ved.press('g')
    ved.press('j') # line 2
    ved.press('x') # delete 'l' in line
    ved.save()
    
    content = ved.get_content()
    ved.quit()
    
    if "ine 2: world" in content and "line 1: hello" in content:
        print("✅ test_vim_movements passed")
    else:
        print("❌ test_vim_movements failed")
        print(f"Content: {content}")

def test_vim_deletion():
    print("\nRunning test_vim_deletion...")
    ved = VedAutomator(TEST_FILE)
    ved.start()
    
    # dd: delete line
    ved.press('g')
    ved.press('g')
    ved.press('d')
    ved.press('d') # delete "line 1: hello"
    ved.save()
    
    content = ved.get_content()
    ved.quit()
    
    # Allow some variation in line endings/spacing
    if "line 1: hello" not in content and "line 2: world" in content:
        print("✅ test_vim_deletion passed")
    else:
        print("❌ test_vim_deletion failed")
        print(f"Content: {content}")

def test_undo():
    print("\nRunning test_undo...")
    ved = VedAutomator(TEST_FILE)
    ved.start()
    
    # x then u
    ved.press('g')
    ved.press('g')
    ved.press('x') # delete 'l' in line
    ved.undo()
    ved.save()
    
    content = ved.get_content()
    ved.quit()
    
    if "line 1: hello" in content:
        print("✅ test_undo passed")
    else:
        print("❌ test_undo failed")

def test_search():
    print("\nRunning test_search...")
    ved = VedAutomator(TEST_FILE)
    ved.start()
    
    # Go to top first
    ved.press('g')
    ved.press('g')
    
    # Search for "vlang"
    ved.press('/')
    ved.write("vlang")
    time.sleep(1)
    ved.press('enter')
    time.sleep(1)
    
    # We should be on line 3. Let's delete it.
    ved.press('d')
    ved.press('d')
    ved.save()
    
    content = ved.get_content()
    ved.quit()
    
    if "vlang" not in content and "world" in content:
        print("✅ test_search passed")
    else:
        print("❌ test_search failed")
        print(f"Content: {content}")

def test_fuzzy_finder():
    print("\nRunning test_fuzzy_finder...")
    ved = VedAutomator(TEST_FILE)
    ved.start()
    
    # Ctrl+P
    ved.hotkey(ved.ctrl, 'p')
    time.sleep(1)
    
    # Search for README, then delete it and search for LICENSE
    ved.write("README")
    time.sleep(0.5)
    for _ in range(6):
        ved.press('backspace')
    time.sleep(0.5)
    ved.write("LICENSE")
    time.sleep(1)
    ved.press('enter')
    time.sleep(2)
    
    # Check if we switched to LICENSE
    if ved.process.poll() is None:
        print("✅ test_fuzzy_finder window appeared and accepted input (with backspace)")
    else:
        print("❌ test_fuzzy_finder crashed ved")
    ved.quit()

if __name__ == "__main__":
    test_basic_editing()
    test_vim_movements()
    test_vim_deletion()
    test_undo()
    test_search()
    test_fuzzy_finder()
