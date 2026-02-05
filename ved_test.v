// Copyright (c) 2019-2025 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by a GPL license
// that can be found in the LICENSE file.
module main

// import os

// create_test_ved 创建一个用于测试的 Ved 实例
fn create_test_ved() &Ved {
	mut ved := &Ved{
		page_height:   24
		win_width:     800
		win_height:    600
		nr_splits:     1
		cur_split:     0
		mode:          .normal
		workspace:     '/tmp/test_workspace'
		workspace_idx: 0
		cfg:           Config{
			char_width: 8
			tab_size:   4
		}
		cb:            unsafe { nil }
	}
	// Initialize views
	ved.views = []View{len: ved.nr_splits, init: ved.new_view()}
	if ved.views.len > 0 {
		ved.view = &ved.views[0]
	}
	ved.open_paths = [][]string{len: max_nr_workspaces, init: []string{}}
	return ved
}

// Test Ved initialization
fn test_ved_initialization() {
	mut ved := create_test_ved()

	assert ved.win_width == 800
	assert ved.win_height == 600
	assert ved.mode == .normal
	assert ved.nr_splits == 1
	assert ved.cur_split == 0
	assert ved.views.len == 1
}

// Test mode switching
fn test_ved_mode_switching() {
	mut ved := create_test_ved()

	// Start in normal mode
	assert ved.mode == .normal

	// Switch to insert mode
	ved.mode = .insert
	assert ved.mode == .insert

	// Switch back to normal
	ved.mode = .normal
	assert ved.mode == .normal

	// Switch to visual mode
	ved.mode = .visual
	assert ved.mode == .visual

	// Switch to query mode
	ved.mode = .query
	assert ved.mode == .query
}

// Test view switching
fn test_ved_view_switching() {
	mut ved := create_test_ved()
	ved.nr_splits = 2
	ved.views = []View{len: ved.nr_splits, init: ved.new_view()}

	// Initially at view 0
	ved.view = &ved.views[0]
	assert ved.cur_split == 0

	// Switch to view 1
	ved.cur_split = 1
	ved.view = &ved.views[1]
	assert ved.cur_split == 1
}

// Test workspace management
fn test_ved_workspace() {
	mut ved := create_test_ved()

	assert ved.workspace == '/tmp/test_workspace'
	assert ved.workspace_idx == 0

	// Test changing workspace
	ved.workspace = '/tmp/another_workspace'
	assert ved.workspace == '/tmp/another_workspace'
}

// Test query functionality
fn test_ved_query() {
	mut ved := create_test_ved()

	// Test setting query
	ved.query = 'test query'
	assert ved.query == 'test query'

	// Test clearing query
	ved.query = ''
	assert ved.query == ''
}

// Test search history
fn test_ved_search_history() {
	mut ved := create_test_ved()

	// Add search queries
	ved.search_history << 'first search'
	ved.search_history << 'second search'

	assert ved.search_history.len == 2
	assert ved.search_history[0] == 'first search'
	assert ved.search_history[1] == 'second search'
}

// Test file position tracking
fn test_ved_file_y_pos() {
	mut ved := create_test_ved()

	// Set position for a file
	ved.file_y_pos['/tmp/test.txt'] = 42

	assert ved.file_y_pos['/tmp/test.txt'] == 42
}

// Test ylines (yank buffer)
fn test_ved_ylines() {
	mut ved := create_test_ved()

	// Add lines to yank buffer
	ved.ylines << 'line 1'
	ved.ylines << 'line 2'

	assert ved.ylines.len == 2
	assert ved.ylines[0] == 'line 1'
	assert ved.ylines[1] == 'line 2'
}

// Test prev_cmd tracking
fn test_ved_prev_cmd() {
	mut ved := create_test_ved()

	ved.prev_cmd = 'dd'
	assert ved.prev_cmd == 'dd'

	ved.prev_cmd = 'yy'
	assert ved.prev_cmd == 'yy'
}

// Test marked_text (IME input)
fn test_ved_marked_text() {
	mut ved := create_test_ved()

	ved.marked_text = '你好'
	assert ved.marked_text == '你好'

	ved.marked_text = ''
	assert ved.marked_text == ''
}

// Test timer functionality
fn test_ved_timer() {
	mut ved := create_test_ved()

	// Timer should be initialized with default values
	assert ved.timer.pom_is_started == false
	assert ved.timer.tasks.len == 0
}

// Test new_view creates proper view
fn test_ved_new_view() {
	mut ved := create_test_ved()

	view := ved.new_view()

	assert view.x == 0
	assert view.y == 0
	assert view.page_height == ved.page_height
	assert view.vstart == -1
	assert view.vend == -1
}

// Test split width calculation
fn test_ved_split_width() {
	mut ved := create_test_ved()
	ved.win_width = 800
	ved.nr_splits = 1

	// Single split should use full width (minus padding)
	width := ved.split_width()
	assert width > 0
	assert width <= 800
}

// Test multiple splits width
fn test_ved_multiple_splits_width() {
	mut ved := create_test_ved()
	ved.win_width = 800
	ved.nr_splits = 2
	ved.views = []View{len: ved.nr_splits, init: ved.new_view()}

	width := ved.split_width()
	// Two splits should divide the width
	assert width > 0
	assert width < 800
}

// Test cur_task tracking
fn test_ved_cur_task() {
	mut ved := create_test_ved()

	ved.cur_task = 'Implement feature X'
	assert ved.cur_task == 'Implement feature X'
}

// Test error_line
fn test_ved_error_line() {
	mut ved := create_test_ved()

	ved.error_line = 'Error: file not found'
	assert ved.error_line == 'Error: file not found'
}

// Test refresh flag
fn test_ved_refresh_flag() {
	mut ved := create_test_ved()

	// Default should be true
	assert ved.refresh == true

	ved.refresh = false
	assert ved.refresh == false
}

// Test just_switched flag
fn test_ved_just_switched() {
	mut ved := create_test_ved()

	ved.just_switched = true
	assert ved.just_switched == true

	ved.just_switched = false
	assert ved.just_switched == false
}

// Test char_width
fn test_ved_char_width() {
	mut ved := create_test_ved()

	ved.char_width = 10
	assert ved.char_width == 10
}

// Test open_paths management
fn test_ved_open_paths() {
	mut ved := create_test_ved()
	ved.open_paths = [][]string{len: max_nr_workspaces, init: []string{}}

	// Add files to workspace 0
	ved.open_paths[0] << 'file1.v'
	ved.open_paths[0] << 'file2.v'

	assert ved.open_paths[0].len == 2
	assert ved.open_paths[0][0] == 'file1.v'
	assert ved.open_paths[0][1] == 'file2.v'
}

// Test prev_key tracking
fn test_ved_prev_key() {
	mut ved := create_test_ved()

	// Test that prev_key starts as invalid
	assert ved.prev_key == .invalid
}

// Test prev_key_str
fn test_ved_prev_key_str() {
	mut ved := create_test_ved()

	ved.prev_key_str = '('
	assert ved.prev_key_str == '('
}

// Test prev_insert for dot command
fn test_ved_prev_insert() {
	mut ved := create_test_ved()

	ved.prev_insert = 'hello world'
	assert ved.prev_insert == 'hello world'
}

// Test search_query
fn test_ved_search_query() {
	mut ved := create_test_ved()

	ved.search_query = 'search term'
	assert ved.search_query == 'search term'
}

// Test search_idx
fn test_ved_search_idx() {
	mut ved := create_test_ved()

	ved.search_idx = 5
	assert ved.search_idx == 5
}

// Test cq_in_a_row
fn test_ved_cq_in_a_row() {
	mut ved := create_test_ved()

	ved.cq_in_a_row = 3
	assert ved.cq_in_a_row == 3
}

// Test search_dir
fn test_ved_search_dir() {
	mut ved := create_test_ved()

	ved.search_dir = '/tmp'
	assert ved.search_dir == '/tmp'
}

// Test search_dir_idx
fn test_ved_search_dir_idx() {
	mut ved := create_test_ved()

	ved.search_dir_idx = 2
	assert ved.search_dir_idx == 2
}

// Test cur_fn_name
fn test_ved_cur_fn_name() {
	mut ved := create_test_ved()

	ved.cur_fn_name = 'main'
	assert ved.cur_fn_name == 'main'
}

// Test task_start_unix
fn test_ved_task_start_unix() {
	mut ved := create_test_ved()

	ved.task_start_unix = 1234567890
	assert ved.task_start_unix == 1234567890
}

// Test all_git_files
fn test_ved_all_git_files() {
	mut ved := create_test_ved()

	ved.all_git_files << 'file1.v'
	ved.all_git_files << 'file2.v'

	assert ved.all_git_files.len == 2
}

// Test git_diff tracking
fn test_ved_git_diff() {
	mut ved := create_test_ved()

	ved.git_diff_plus = '+10'
	ved.git_diff_minus = '-5'

	assert ved.git_diff_plus == '+10'
	assert ved.git_diff_minus == '-5'
}

// Test current_syntax_idx
fn test_ved_current_syntax_idx() {
	mut ved := create_test_ved()

	ved.current_syntax_idx = 2
	assert ved.current_syntax_idx == 2
}

// Test is_building flag
fn test_ved_is_building() {
	mut ved := create_test_ved()

	ved.is_building = true
	assert ved.is_building == true

	ved.is_building = false
	assert ved.is_building == false
}
