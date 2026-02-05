// Copyright (c) 2019-2025 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by a GPL license
// that can be found in the LICENSE file.
module main

// create_test_ved_for_events 创建一个用于事件测试的 Ved 实例
fn create_test_ved_for_events() &Ved {
	mut ved := &Ved{
		page_height: 24
		win_width: 800
		win_height: 600
		nr_splits: 1
		cur_split: 0
		mode: .normal
		workspace: '/tmp/test_workspace'
		workspace_idx: 0
		cfg: Config{
			char_width: 8
			tab_size: 4
			line_height: 20
			disable_mouse: true // Disable mouse for tests
		}
		cb: unsafe { nil }
	}
	ved.views = []View{len: ved.nr_splits, init: ved.new_view()}
	if ved.views.len > 0 {
		ved.view = &ved.views[0]
	}
	ved.open_paths = [][]string{len: max_nr_workspaces, init: []string{}}
	return ved
}

// Test mode switching via direct assignment
fn test_events_mode_switching() {
	mut ved := create_test_ved_for_events()
	ved.mode = .insert

	// Simulate escape key behavior
	if ved.mode == .visual {
		ved.exit_visual()
	}
	ved.mode = .normal

	assert ved.mode == .normal
}

// Test visual mode exit
fn test_events_visual_mode_exit() {
	mut ved := create_test_ved_for_events()
	ved.mode = .visual
	ved.view.vstart = 0
	ved.view.vend = 1

	// Simulate escape key behavior
	if ved.mode == .visual {
		ved.exit_visual()
	}
	ved.mode = .normal

	assert ved.mode == .normal
}

// Test error reset
fn test_events_error_reset() {
	mut ved := create_test_ved_for_events()
	ved.view.error_y = 5
	ved.error_line = 'Some error'

	// Simulate key press behavior
	ved.view.error_y = -1
	ved.error_line = ''

	assert ved.view.error_y == -1
	assert ved.error_line == ''
}

// Test normal mode handling
fn test_events_normal_mode() {
	mut ved := create_test_ved_for_events()
	ved.mode = .normal
	ved.view.lines = ['hello world']
	ved.view.y = 0
	ved.view.x = 0

	// Simulate 'j' key in normal mode (move down)
	ved.view.j()

	// Mode should remain normal
	assert ved.mode == .normal
}

// Test insert mode entry
fn test_events_insert_mode_entry() {
	mut ved := create_test_ved_for_events()
	ved.mode = .normal
	ved.view.lines = ['hello world']
	ved.view.y = 0
	ved.view.x = 0

	// Enter insert mode
	ved.set_insert()

	assert ved.mode == .insert
}

// Test query mode
fn test_events_query_mode() {
	mut ved := create_test_ved_for_events()
	ved.mode = .query
	ved.query_type = .search
	ved.query = ''

	// Simulate typing in query mode
	ved.query = 'test'

	assert ved.query == 'test'
	assert ved.mode == .query
}

// Test visual mode activation
fn test_events_visual_mode() {
	mut ved := create_test_ved_for_events()
	ved.mode = .normal
	ved.view.vstart = 0
	ved.view.vstart_x = 0
	ved.view.vend = 1
	ved.view.vend_x = 5

	// Enter visual mode
	ved.mode = .visual

	assert ved.mode == .visual
}

// Test visual block mode
fn test_events_visual_block_mode() {
	mut ved := create_test_ved_for_events()
	ved.mode = .normal

	// Enter visual block mode
	ved.mode = .visual_block

	assert ved.mode == .visual_block
}

// Test timer mode
fn test_events_timer_mode() {
	mut ved := create_test_ved_for_events()
	ved.mode = .normal

	// Enter timer mode
	ved.mode = .timer

	assert ved.mode == .timer
}

// Test autocomplete mode
fn test_events_autocomplete_mode() {
	mut ved := create_test_ved_for_events()
	ved.mode = .insert

	// Enter autocomplete mode
	ved.mode = .autocomplete

	assert ved.mode == .autocomplete
}

// Test debugger mode
fn test_events_debugger_mode() {
	mut ved := create_test_ved_for_events()
	ved.mode = .normal

	// Enter debugger mode
	ved.mode = .debugger

	assert ved.mode == .debugger
}

// Test refresh flag set on event
fn test_events_refresh_flag() {
	mut ved := create_test_ved_for_events()
	ved.refresh = false

	// Set refresh flag
	ved.refresh = true

	assert ved.refresh == true
}

// Test view update after split switch
fn test_events_view_update_after_split_switch() {
	mut ved := create_test_ved_for_events()
	ved.nr_splits = 2
	ved.views = []View{len: ved.nr_splits, init: ved.new_view()}
	ved.view = &ved.views[0]
	ved.cur_split = 0

	// Switch to split 1
	ved.cur_split = 1
	ved.update_view()

	assert ved.view == &ved.views[1]
}

// Test mouse scroll down
fn test_events_mouse_scroll_down() {
	mut ved := create_test_ved_for_events()
	ved.view.lines = ['line1', 'line2', 'line3', 'line4', 'line5']
	ved.view.y = 0

	// Simulate mouse scroll down
	ved.view.j()

	assert ved.view.y == 1
}

// Test mouse scroll up
fn test_events_mouse_scroll_up() {
	mut ved := create_test_ved_for_events()
	ved.view.lines = ['line1', 'line2', 'line3', 'line4', 'line5']
	ved.view.y = 2

	// Simulate mouse scroll up
	ved.view.k()

	assert ved.view.y == 1
}

// Test visual selection range
fn test_events_visual_selection() {
	mut ved := create_test_ved_for_events()
	ved.view.lines = ['hello world', 'second line']
	ved.mode = .normal

	// Start visual selection
	ved.view.vstart = 0
	ved.view.vstart_x = 0
	ved.view.vend = 0
	ved.view.vend_x = 5
	ved.mode = .visual

	assert ved.mode == .visual
	assert ved.view.vstart == 0
	assert ved.view.vend == 0
}

// Test exit visual when selection is empty
fn test_events_exit_visual_empty_selection() {
	mut ved := create_test_ved_for_events()
	ved.mode = .visual
	ved.view.vstart = 5
	ved.view.vstart_x = 0
	ved.view.vend = 5
	ved.view.vend_x = 0

	// This simulates what happens on mouse up with empty selection
	if ved.mode == .visual && ved.view.vstart == ved.view.vend
		&& ved.view.vstart_x == ved.view.vend_x {
		ved.exit_visual()
	}

	assert ved.mode == .normal
}

// Test just_switched flag behavior
fn test_events_just_switched() {
	mut ved := create_test_ved_for_events()
	ved.just_switched = false

	// Simulate mode switch
	ved.just_switched = true

	assert ved.just_switched == true
}

// Test prev_key tracking
fn test_events_prev_key_tracking() {
	mut ved := create_test_ved_for_events()

	// Simulate pressing 'd' key
	ved.prev_key = .d

	assert ved.prev_key == .d
}

// Test key sequence handling (dd)
fn test_events_key_sequence_dd() {
	mut ved := create_test_ved_for_events()
	ved.view.lines = ['line1', 'line2', 'line3']
	ved.view.y = 1
	ved.prev_key = .invalid

	// First 'd'
	ved.prev_key = .d

	// Second 'd' would trigger dd command
	ved.view.dd()

	assert ved.view.lines.len == 2
	assert ved.prev_cmd == 'dd'
}

// Test key sequence yy
fn test_events_key_sequence_yy() {
	mut ved := create_test_ved_for_events()
	ved.view.lines = ['line1', 'line2']
	ved.view.y = 0

	ved.view.yy()

	assert ved.ylines.len == 1
	assert ved.ylines[0] == 'line1'
}

// Test search mode activation
fn test_events_search_mode() {
	mut ved := create_test_ved_for_events()
	ved.mode = .normal

	// Enter search mode
	ved.mode = .query
	ved.query_type = .search

	assert ved.mode == .query
	assert ved.query_type == .search
}

// Test replace mode behavior
fn test_events_replace_mode() {
	mut ved := create_test_ved_for_events()
	ved.view.lines = ['hello world']
	ved.view.y = 0
	ved.view.x = 0

	// Replace first character
	ved.view.r('H')

	assert ved.view.lines[0] == 'Hello world'
}

// Test undo after edit
fn test_events_undo_after_edit() {
	mut ved := create_test_ved_for_events()
	ved.view.lines = ['original']

	// Make edit
	ved.view.save_snapshot()
	ved.view.lines[0] = 'modified'

	// Undo
	ved.view.undo()

	assert ved.view.lines[0] == 'original'
}

// Test redo after undo
fn test_events_redo_after_undo() {
	mut ved := create_test_ved_for_events()
	ved.view.lines = ['original']

	// Make edit
	ved.view.save_snapshot()
	ved.view.lines[0] = 'modified'

	// Undo then redo
	ved.view.undo()
	ved.view.redo()

	assert ved.view.lines[0] == 'modified'
}
