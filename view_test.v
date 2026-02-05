// Copyright (c) 2019-2025 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by a GPL license
// that can be found in the LICENSE file.
module main

import os

// create_test_ved 创建一个用于测试的 Ved 实例
fn create_test_ved_for_view() &Ved {
	mut ved := &Ved{
		page_height:   24
		cfg:           Config{
			char_width: 8
			tab_size:   4
		}
		workspace:     '/tmp/test'
		workspace_idx: 0
	}
	ved.views = []View{len: 1, init: ved.new_view()}
	ved.view = &ved.views[0]
	return ved
}

// create_test_view 创建一个用于测试的 View 实例
fn create_test_view() View {
	mut ved := create_test_ved_for_view()
	mut view := ved.new_view()
	view.ved = ved
	return view
}

// Test View initialization
fn test_view_initialization() {
	mut view := create_test_view()

	assert view.x == 0
	assert view.y == 0
	assert view.from == 0
	assert view.lines.len == 0
	assert view.undo_stack.len == 0
	assert view.redo_stack.len == 0
}

// Test line operations
fn test_view_line_operations() {
	mut view := create_test_view()
	view.lines = ['hello world', 'second line', 'third line']

	// Test line() function
	assert view.line() == 'hello world'

	// Test set_y and line
	view.set_y(1)
	assert view.line() == 'second line'

	view.set_y(2)
	assert view.line() == 'third line'
}

// Test cursor movement - j (down)
fn test_view_cursor_j() {
	mut view := create_test_view()
	view.lines = ['line1', 'line2', 'line3']
	view.y = 0

	view.j()
	assert view.y == 1

	view.j()
	assert view.y == 2

	// Should not go beyond last line
	view.j()
	assert view.y == 2
}

// Test cursor movement - k (up)
fn test_view_cursor_k() {
	mut view := create_test_view()
	view.lines = ['line1', 'line2', 'line3']
	view.y = 2

	view.k()
	assert view.y == 1

	view.k()
	assert view.y == 0

	// Should not go below 0
	view.k()
	assert view.y == 0
}

// Test cursor movement - h (left)
fn test_view_cursor_h() {
	mut view := create_test_view()
	view.lines = ['hello']
	view.x = 3

	view.h()
	assert view.x == 2

	view.h()
	assert view.x == 1

	view.h()
	assert view.x == 0

	// Should not go below 0
	view.h()
	assert view.x == 0
}

// Test cursor movement - l (right)
fn test_view_cursor_l() {
	mut view := create_test_view()
	view.lines = ['hello']
	view.x = 0

	view.l()
	assert view.x == 1

	view.l()
	assert view.x == 2

	// Should stop at end of line
	view.x = 4
	view.l()
	assert view.x == 5

	view.l()
	assert view.x == 5 // Should not exceed line length
}

// Test insert_text
fn test_view_insert_text() {
	mut view := create_test_view()
	view.lines = ['hello world']
	view.x = 5

	view.insert_text(' V')
	assert view.lines[0] == 'hello V world'
	assert view.x == 7
}

// Test insert_text at beginning
fn test_view_insert_text_at_beginning() {
	mut view := create_test_view()
	view.lines = ['world']
	view.x = 0

	view.insert_text('hello ')
	assert view.lines[0] == 'hello world'
	assert view.x == 6
}

// Test insert_text in empty line
fn test_view_insert_text_empty_line() {
	mut view := create_test_view()
	view.lines = ['']
	view.x = 0

	view.insert_text('test')
	assert view.lines[0] == 'test'
	assert view.x == 4
}

// Test backspace
fn test_view_backspace() {
	mut view := create_test_view()
	view.lines = ['hello']
	view.x = 5

	view.backspace()
	assert view.lines[0] == 'hell'
	assert view.x == 4

	view.backspace()
	assert view.lines[0] == 'hel'
	assert view.x == 3
}

// Test backspace at line start (join with previous)
fn test_view_backspace_join_lines() {
	mut view := create_test_view()
	view.lines = ['hello', 'world']
	view.y = 1
	view.x = 0

	view.backspace()
	assert view.lines.len == 1
	assert view.lines[0] == 'helloworld'
	assert view.y == 0
	assert view.x == 5
}

// Test undo/redo
fn test_view_undo_redo() {
	mut view := create_test_view()
	view.lines = ['original']

	// Make a change
	view.save_snapshot()
	view.lines[0] = 'modified'

	// Undo
	view.undo()
	assert view.lines[0] == 'original'

	// Redo
	view.redo()
	assert view.lines[0] == 'modified'
}

// Test dd (delete line)
fn test_view_dd() {
	mut view := create_test_view()
	view.lines = ['line1', 'line2', 'line3']
	view.y = 1

	view.dd()
	assert view.lines.len == 2
	assert view.lines[0] == 'line1'
	assert view.lines[1] == 'line3'
}

// Test yy (yank line) and p (paste)
fn test_view_yy_and_p() {
	mut view := create_test_view()
	view.lines = ['line1', 'line2']
	view.y = 0

	view.yy()
	assert view.ved.ylines.len == 1
	assert view.ved.ylines[0] == 'line1'

	view.p()
	assert view.lines.len == 3
	assert view.lines[1] == 'line1'
}

// Test o (open new line below)
fn test_view_o() {
	mut view := create_test_view()
	view.lines = ['line1']
	view.y = 0

	view.o()
	assert view.lines.len == 2
	assert view.y == 1
}

// Test shift_o (open new line above)
fn test_view_shift_o() {
	mut view := create_test_view()
	view.lines = ['line1']
	view.y = 0

	view.shift_o()
	assert view.lines.len == 2
	assert view.y == 0
}

// Test w (word forward)
fn test_view_w() {
	mut view := create_test_view()
	view.lines = ['hello world test']
	view.x = 0

	view.w()
	assert view.x > 0

	view.w()
	assert view.x > 6
}

// Test b (word backward)
fn test_view_b() {
	mut view := create_test_view()
	view.lines = ['hello world test']
	view.x = 16

	view.b()
	assert view.x < 16

	view.b()
	assert view.x < 6
}

// Test zero (go to line start)
fn test_view_zero() {
	mut view := create_test_view()
	view.lines = ['hello world']
	view.x = 10

	view.zero()
	assert view.x == 0
}

// Test dollar (go to line end)
fn test_view_dollar() {
	mut view := create_test_view()
	view.lines = ['hello world']
	view.x = 0

	view.dollar()
	assert view.x == 11
}

// Test gg (go to file start)
fn test_view_gg() {
	mut view := create_test_view()
	view.lines = ['line1', 'line2', 'line3', 'line4', 'line5']
	view.y = 4
	view.from = 2

	view.gg()
	assert view.y == 0
	assert view.from == 0
}

// Test shift_g (go to file end)
fn test_view_shift_g() {
	mut view := create_test_view()
	view.lines = ['line1', 'line2', 'line3']
	view.y = 0

	view.shift_g()
	assert view.y == 2
}

// Test join lines
fn test_view_join() {
	mut view := create_test_view()
	view.lines = ['hello', 'world']
	view.y = 0

	view.join()
	assert view.lines.len == 1
	assert view.lines[0] == 'helloworld'
}

// Test delete_char
fn test_view_delete_char() {
	mut view := create_test_view()
	view.lines = ['hello']
	view.x = 1

	view.delete_char()
	assert view.lines[0] == 'hllo'
}

// Test shift_right (indent)
fn test_view_shift_right() {
	mut view := create_test_view()
	view.lines = ['hello']
	view.y = 0

	view.shift_right()
	assert view.lines[0] == '\thello'
}

// Test shift_left (unindent)
fn test_view_shift_left() {
	mut view := create_test_view()
	view.lines = ['\thello']
	view.y = 0

	view.shift_left()
	assert view.lines[0] == 'hello'
}

// Test set_line
fn test_view_set_line() {
	mut view := create_test_view()
	view.lines = ['old line']
	view.y = 0

	view.set_line('new line')
	assert view.lines[0] == 'new line'
	assert view.changed == true
}

// Test char() function
fn test_view_char() {
	mut view := create_test_view()
	view.lines = ['hello']
	view.x = 0

	assert view.char() == `h`

	view.x = 4
	assert view.char() == `o`
}

// Test save_snapshot limits undo stack
fn test_view_undo_stack_limit() {
	mut view := create_test_view()
	view.lines = ['initial']

	// Add more than 100 snapshots
	for i in 0 .. 105 {
		view.save_snapshot()
		view.lines[0] = 'change ${i}'
	}

	// Stack should be limited to 100
	assert view.undo_stack.len <= 100
}
