module uiold

$if windows {
	#flag -limm32
	#flag -luser32
	#include <windows.h>
}

fn C.GetFocus() voidptr
fn C.GetForegroundWindow() voidptr
fn C.ImmGetContext(voidptr) voidptr
fn C.ImmSetCompositionWindow(voidptr, voidptr) bool
fn C.ImmReleaseContext(voidptr, voidptr) bool
fn C.ImmAssociateContext(voidptr, voidptr) voidptr
fn C.ImmSetOpenStatus(voidptr, bool) bool

struct WinPoint {
	x int
	y int
}

struct WinRect {
	left   int
	top    int
	right  int
	bottom int
}

struct WinCompositionForm {
	dw_style       u32
	pt_current_pos WinPoint
	rc_area        WinRect
}

fn focus_app(next voidptr, event voidptr, data voidptr) {
}

pub fn reg_key_ved() {
}

fn get_hwnd() voidptr {
	mut hwnd := C.GetFocus()
	if hwnd == 0 {
		hwnd = C.GetForegroundWindow()
	}
	return hwnd
}

pub fn set_ime_position(x int, y int, h int) {
	$if windows {
		hwnd := get_hwnd()
		if hwnd != 0 {
			himc := C.ImmGetContext(hwnd)
			if himc != 0 {
				// 坐标补偿：Ved 使用 scale: 2，所以我们将逻辑坐标乘以 2
				// 如果显示位置不对，可能需要根据 DPI 动态调整，但目前先试 2
				cf := WinCompositionForm{
					dw_style: 0x0002 // CFS_POINT
					pt_current_pos: WinPoint{x * 2, y * 2}
				}
				C.ImmSetCompositionWindow(himc, &cf)
				C.ImmReleaseContext(hwnd, himc)
			}
		}
	}
}

pub fn focus_native_input(focus bool) {
	$if windows {
		hwnd := get_hwnd()
		if hwnd != 0 {
			himc := C.ImmGetContext(hwnd)
			if himc != 0 {
				if focus {
					C.ImmAssociateContext(hwnd, himc)
					C.ImmSetOpenStatus(himc, true)
				}
				C.ImmReleaseContext(hwnd, himc)
			}
		}
	}
}

pub fn reg_ved_insert_cb(cb voidptr) {
}

pub fn reg_ved_marked_cb(cb voidptr) {
}

pub fn reg_ved_instance(ved voidptr) {
}
