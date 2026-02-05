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
BASE_CONTENT = "INITIAL CONTENT\n"

def build_ved():
    print("Building ved...")
    res = subprocess.run(["v", "."], cwd=CWD)
    if res.returncode != 0:
        print("Build failed!")
        return False
    print("Build successful.")
    return True

def run_test():
    # Preparation
    if TEST_FILE.exists():
        TEST_FILE.unlink()
    TEST_FILE.write_text(BASE_CONTENT)
    
    print(f"Starting test with file: {TEST_FILE}")
    
    # Run ved in windowed mode
    env = os.environ.copy()
    env["VED_TEST"] = "1"
    # Use -window to ensure it doesn't try to go fullscreen by default in some environments
    cmd = [str(VED_BIN), "-window", str(TEST_FILE)]
    process = subprocess.Popen(cmd, env=env)
    
    success = False
    try:
        # Give it time to start
        time.sleep(3)
        
        def focus_ved():
            if platform.system() == "Darwin":
                os.system(f"osascript -e 'tell application \"System Events\" to set frontmost of process \"ved\" to true' 2>/dev/null")
            time.sleep(0.5)

        # Initial focus
        focus_ved()
        
        # Enter insert mode
        print("Entering insert mode...")
        pyautogui.press('i')
        time.sleep(0.5)
        
        # Type content
        print("Typing content...")
        pyautogui.write("newtext", interval=0.1)
        time.sleep(1)
        
        # Type Chinese content
        print("Typing Chinese content via clipboard...")
        pyperclip.copy("中文内容")
        focus_ved() # Re-focus before sensitive hotkeys
        if platform.system() == "Darwin":
            pyautogui.hotkey('command', 'v')
        else:
            pyautogui.hotkey('ctrl', 'v')
        time.sleep(1)
        
        # Save file
        print("Saving file...")
        focus_ved()
        if platform.system() == "Darwin":
            pyautogui.hotkey('command', 's')
        else:
            pyautogui.hotkey('ctrl', 's')
        time.sleep(1)
        
        # Escape to normal mode
        pyautogui.press('esc')
        time.sleep(0.5)
        
        # Quit: Only if process is still alive to avoid sending Cmd+Q to other apps
        if process.poll() is None:
            print("Quitting (Cmd+Q x2)...")
            focus_ved()
            if platform.system() == "Darwin":
                pyautogui.hotkey('command', 'q')
                time.sleep(0.2)
                focus_ved() # Double check focus for the second Q
                pyautogui.hotkey('command', 'q')
            else:
                pyautogui.hotkey('ctrl', 'q')
                time.sleep(0.2)
                pyautogui.hotkey('ctrl', 'q')
        
        # Wait for finish
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            print("Process didn't exit, terminating...")
            process.terminate()
            
        # Verify
        if TEST_FILE.exists():
            content = TEST_FILE.read_text()
            print(f"Final file content: [{content}]")
            passed = True
            if "newtext" in content:
                print("✅ Found 'newtext'")
            else:
                print("❌ 'newtext' NOT found")
                passed = False
            
            if "中文内容" in content:
                print("✅ Found '中文内容'")
            else:
                print("❌ '中文内容' NOT found")
                passed = False
                
            if passed:
                print("\n✅ TEST PASSED")
                success = True
            else:
                print("\n❌ TEST FAILED")
        else:
            print("\n❌ TEST FAILED: Test file disappeared.")
            
    finally:
        # Cleanup only on success to allow debugging of failed tests
        if success and TEST_FILE.exists():
            TEST_FILE.unlink()
            pass
        elif not success:
            print(f"Test failed. Evidence preserved at: {TEST_FILE}")

if __name__ == "__main__":
    if "--build" in sys.argv:
        if not build_ved():
            sys.exit(1)
    run_test()
