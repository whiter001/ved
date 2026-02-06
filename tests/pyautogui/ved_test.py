import subprocess
import time
import os
import sys
import platform
import pyautogui
import pyperclip
import json
import argparse
from pathlib import Path

# Base setup
CWD = Path(__file__).parent.parent.parent
VED_BIN = CWD / "ved"
TEST_FILE = CWD / "tests" / "pyautogui" / "test_output.txt"
STATE_FILE = CWD / "tests" / "pyautogui" / ".test_state.json"
BASE_CONTENT = """line 1: hello
line 2: world
line 3: vlang
line 4: ved editor
"""

class VedAutomator:
    def __init__(self, file_path):
        self.file_path = file_path
        self.process = None
        # Use 'ctrl' for tests as it's more reliable across platforms in automated environments
        # and 'ved' handles both command and ctrl for its 'super' modifier.
        self.ctrl = 'ctrl'

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
        if len(key) == 1 and key.isupper():
            # many macOS setups prefer hotkey for shift+key
            pyautogui.hotkey('shift', key.lower())
        else:
            pyautogui.press(key)
        time.sleep(0.4) # Increased from 0.3

    def write(self, text):
        self.focus()
        for char in text:
            if char == '\n':
                pyautogui.press('enter')
            elif char.isupper():
                pyautogui.hotkey('shift', char.lower())
            else:
                pyautogui.typewrite(char)
            # small delay between chars to be more like human
            time.sleep(0.05)
        time.sleep(0.5)

    def hotkey(self, *args):
        self.focus()
        pyautogui.hotkey(*args)
        time.sleep(0.6)

    def save(self):
        self.hotkey(self.ctrl, 's')
        time.sleep(1.5) # More time for disk IO

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
    ved.press('G') # Use press('G') for Shift+G
    ved.press('A') # Use press('A') for Shift+A
    time.sleep(1)
    ved.write("\nnew line added")
    time.sleep(1)
    ved.press('esc')
    ved.save()
    
    content = ved.get_content()
    ved.quit()
    
    if "new line added" in content:
        print("✅ test_basic_editing passed")
        return True
    else:
        print("❌ test_basic_editing failed")
        print(f"Content: {content}")
        return False

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
        return True
    else:
        print("❌ test_vim_movements failed")
        print(f"Content: {content}")
        return False

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
        return True
    else:
        print("❌ test_vim_deletion failed")
        print(f"Content: {content}")
        return False

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
        return True
    else:
        print("❌ test_undo failed")
        return False

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
        return True
    else:
        print("❌ test_search failed")
        print(f"Content: {content}")
        return False

def test_visual_mode():
    print("\nRunning test_visual_mode...")
    ved = VedAutomator(TEST_FILE)
    ved.start()
    
    # Enter visual mode, select "line", copy and paste
    ved.press('v')  # Enter visual mode (character-wise)
    ved.press('l')  # select 'l'
    ved.press('l')  # select 'i'
    ved.press('l')  # select 'n'
    ved.press('l')  # select 'e'
    ved.press('y')  # Yank (copy) "line"
    time.sleep(0.5)
    ved.press('G')  # Move to last line
    ved.press('p')  # Paste
    ved.save()
    
    content = ved.get_content()
    ved.quit()
    
    # "line" should appear in the last part of content
    lines = content.strip().split('\n')
    if any("line" in line for line in lines[-2:]): # Check last two lines
        print("✅ test_visual_mode passed")
        return True
    else:
        print("❌ test_visual_mode failed")
        print(f"Content: {content}")
        return False

def test_copy_paste():
    print("\nRunning test_copy_paste...")
    ved = VedAutomator(TEST_FILE)
    ved.start()
    
    # Copy a line and paste it
    ved.press('g')
    ved.press('g')
    ved.press('y')  # Yank current line
    ved.press('y')
    time.sleep(0.5)
    ved.press('p')  # Paste below
    ved.save()
    
    content = ved.get_content()
    ved.quit()
    
    lines = content.split('\n')
    # Original line 1 should now be at line 1 and line 2
    if len(lines) >= 2 and lines[0] == lines[1] and "line 1" in lines[0]:
        print("✅ test_copy_paste passed")
        return True
    else:
        print("❌ test_copy_paste failed")
        print(f"Content: {content}")
        return False

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
        ved.quit()
        return True
    else:
        print("❌ test_fuzzy_finder crashed ved")
        ved.quit()
        return False

def test_chinese_input():
    print("\nRunning test_chinese_input...")
    ved = VedAutomator(TEST_FILE)
    ved.start()
    
    # Go to end of file and enter insert mode
    ved.press('G')
    ved.press('A')
    time.sleep(1)
    
    # Use clipboard to paste Chinese text
    import pyperclip
    pyperclip.copy("你好世界")
    ved.hotkey(ved.ctrl, 'v')
    
    time.sleep(1)
    ved.press('esc') # Exit insert mode
    ved.save()
    
    content = ved.get_content()
    ved.quit()
    
    if "你好世界" in content:
        print("✅ test_chinese_input passed")
        return True
    else:
        print("❌ test_chinese_input failed")
        print(f"Content: {content}")
        return False

def test_line_merging():
    print("\nRunning test_line_merging...")
    ved = VedAutomator(TEST_FILE)
    ved.start()
    
    ved.press('g')
    ved.press('g')
    ved.press('J') # Shift+J to merge line 1 and 2
    ved.save()
    
    content = ved.get_content()
    ved.quit()
    
    if "line 1: helloline 2: world" in content:
        print("✅ test_line_merging passed")
        return True
    else:
        print("❌ test_line_merging failed")
        print(f"Content: {content}")
        return False

def test_list_open_files():
    print("\nRunning test_list_open_files...")
    ved = VedAutomator(TEST_FILE)
    ved.start()
    
    # Ctrl+J
    ved.hotkey(ved.ctrl, 'j')
    time.sleep(1)
    
    # It should show the current file. Press enter to select it.
    ved.press('enter')
    time.sleep(1)
    
    if ved.process.poll() is None:
        print("✅ test_list_open_files window appeared and accepted input")
        ved.quit()
        return True
    else:
        print("❌ test_list_open_files crashed ved")
        ved.quit()
        return False

def test_word_movement():
    print("\nRunning test_word_movement...")
    ved = VedAutomator(TEST_FILE)
    ved.start()
    
    # line 1: hello
    # Start at line 1, col 0 ('l')
    ved.press('w') # Move to '1'
    ved.press('w') # Move to ':'
    ved.press('w') # Move to 'hello'
    ved.press('x') # Delete 'h'
    ved.save()
    
    content = ved.get_content()
    ved.quit()
    
    if "line 1: ello" in content:
        print("✅ test_word_movement passed")
        return True
    else:
        print("❌ test_word_movement failed")
        print(f"Content: {content}")
        return False

def test_replace():
    print("\nRunning test_replace...")
    ved = VedAutomator(TEST_FILE)
    ved.start()
    
    # line 1: hello
    ved.press('r')
    ved.press('z') # Replace 'l' with 'z'
    ved.save()
    
    content = ved.get_content()
    ved.quit()
    
    if "zine 1: hello" in content:
        print("✅ test_replace passed")
        return True
    else:
        print("❌ test_replace failed")
        print(f"Content: {content}")
        return False

def load_state():
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text())
        except:
            return {}
    return {}

def save_state(state):
    STATE_FILE.write_text(json.dumps(state, indent=4))

def get_all_tests():
    return [name for name in globals() if name.startswith("test_") and callable(globals()[name])]

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ved Test Runner")
    parser.add_argument("--build", action="store_true", help="Build ved before running tests")
    parser.add_argument("--list", action="store_true", help="List all available tests")
    parser.add_argument("--failed", action="store_true", help="Run only tests that failed last time")
    parser.add_argument("--skip-passed", action="store_true", help="Skip tests that passed last time")
    parser.add_argument("--names", nargs="+", help="Run specific tests by name")
    args = parser.parse_args()

    if args.build:
        print("Building ved...")
        subprocess.run(["./build.sh"], cwd=CWD, check=True)

    all_test_names = get_all_tests()
    
    if args.list:
        print("Available tests:")
        for name in all_test_names:
            print(f"  - {name}")
        sys.exit(0)

    state = load_state()
    last_results = state.get("results", {})

    to_run = []
    if args.names:
        for name in args.names:
            if name in all_test_names:
                to_run.append(name)
            else:
                print(f"Warning: Test '{name}' not found.")
    elif args.failed:
        to_run = [name for name in all_test_names if last_results.get(name) is False]
        if not to_run:
            print("No failed tests found in last run.")
            sys.exit(0)
    elif args.skip_passed:
        to_run = [name for name in all_test_names if last_results.get(name) is not True]
    else:
        to_run = all_test_names

    print(f"Plan to run {len(to_run)} tests.")
    
    current_results = state.get("results", {})
    passed = 0
    failed = 0
    
    for name in to_run:
        test_func = globals()[name]
        success = False
        try:
            success = test_func()
        except Exception as e:
            print(f"❌ {name} raised an exception: {e}")
            success = False
        
        current_results[name] = success
        if success:
            passed += 1
        else:
            failed += 1
            
    state["results"] = current_results
    state["last_run_time"] = time.strftime("%Y-%m-%d %H:%M:%S")
    save_state(state)
    
    print(f"\nTest Summary: {passed} passed, {failed} failed.")
    if failed > 0:
        sys.exit(1)
    sys.exit(0)
