module main

// 主模块
import os // 导入 os 模块
import gg // 导入 gg 模块
import uiold // 导入 uiold 模块

// on_event 处理各种 GUI 事件，如鼠标点击、滚动和窗口缩放。
fn (mut ved Ved) on_event(e &gg.Event) {
	ved.refresh = true

	// 处理鼠标滚动
	if e.typ == .mouse_scroll {
		if e.scroll_y < -0.2 {
			ved.view.j()
		} else if e.scroll_y > 0.2 {
			ved.view.k()
		}
	}

	// 处理鼠标点击
	if e.typ == .mouse_down {
		if ved.cfg.disable_mouse {
			return
		}

		ved.mouse_is_down = true
		mut view := ved.view

		// 处理分屏切换点击
		for i := 0; i < ved.nr_splits; i++ {
			sw := ved.split_width()
			starting_x := i * sw
			ending_x := (i + 1) * sw

			if e.mouse_x > starting_x && e.mouse_x < ending_x {
				if ved.cur_split != i {
					ved.cur_split = i
					ved.update_view()
					view = ved.view
				}
			}
		}

		// 计算点击的行号 (e.mouse_y 是逻辑坐标)
		// 标题栏占据了 ved.cfg.line_height 的高度
		clicked_y := int((e.mouse_y - ved.cfg.line_height) / ved.cfg.line_height) + view.from
		if clicked_y >= view.lines.len {
			if view.lines.len == 0 {
				view.set_y(0)
			} else {
				view.set_y(view.lines.len - 1)
			}
		} else if clicked_y < 0 {
			view.set_y(0)
		} else {
			view.set_y(clicked_y)
		}

		// rel_x 是相对于当前视图起始位置的像素偏移
		// split_width() 返回的是逻辑宽度
		sw := ved.split_width()
		rel_x := e.mouse_x - (ved.cur_split % ved.nr_splits) * sw - view.padding_left - 10

		// 将像素转换为视觉列并加上水平滚动偏移
		visual_clicked_x := int(rel_x / ved.cfg.char_width) + view.from_x

		if view.lines.len > 0 {
			// 根据视觉位置获取准确的字节索引
			view.x = view.x_at_visual_pos(int_max(0, visual_clicked_x))
			view.sync_visual_x()
		}

		// 如果不是插入模式，开始可视选择
		if ved.mode != .insert {
			if ved.mode != .visual && ved.mode != .visual_block {
				ved.mode = .visual
			}
			view.vstart = view.y
			view.vend = view.y
			view.vstart_x = view.x
			view.vend_x = view.x
		}

		$if macos {
			if ved.mode == .insert {
				uiold.focus_native_input(true)
			}
		}
	}

	if e.typ == .mouse_move {
		if ved.cfg.disable_mouse {
			return
		}
		// 只有在鼠标左键按下时才处理拖拽选择
		if ved.mouse_is_down {
			if ved.mode == .insert {
				return
			}
			mut view := ved.view

			// 计算当前的行和列 (e.mouse_y 是逻辑坐标)
			clicked_y := int((e.mouse_y - ved.cfg.line_height) / ved.cfg.line_height) + view.from
			if clicked_y >= view.lines.len {
				if view.lines.len > 0 {
					view.set_y(view.lines.len - 1)
				}
			} else if clicked_y < 0 {
				view.set_y(0)
			} else {
				view.set_y(clicked_y)
			}

			sw := ved.split_width()
			rel_x := e.mouse_x - (ved.cur_split % ved.nr_splits) * sw - view.padding_left - 10
			visual_clicked_x := int(rel_x / ved.cfg.char_width) + view.from_x

			if view.lines.len > 0 {
				view.x = view.x_at_visual_pos(int_max(0, visual_clicked_x))
				view.sync_visual_x()
			}

			// 更新选择范围并进入可视模式
			view.vend = view.y
			view.vend_x = view.x
			if ved.mode != .visual && (view.vstart != view.vend || view.vstart_x != view.vend_x) {
				ved.mode = .visual
			}
		}
	}

	if e.typ == .mouse_up {
		ved.mouse_is_down = false
		// 如果选择范围为空，且处于可视模式下，则退出可视模式
		mut view := ved.view
		if ved.mode == .visual && view.vstart == view.vend && view.vstart_x == view.vend_x {
			ved.exit_visual()
		}
	}
}

// key_down 是按键按下时的总入口
fn key_down(key gg.KeyCode, mod gg.Modifier, mut ved Ved) {
	super := mod.has(.super) || mod.has(.ctrl)
	if key == .escape {
		if ved.mode == .visual {
			ved.exit_visual()
		}
		ved.mode = .normal
		$if macos {
			uiold.focus_native_input(false)
		}
	}
	// 重置错误高亮
	ved.view.error_y = -1
	ved.error_line = ''
	match ved.mode {
		.normal { ved.key_normal(key, mod) }
		.visual, .visual_block { ved.key_visual(key, mod) }
		.insert { ved.key_insert(key, mod) }
		.query { ved.key_query(key, super) }
		.timer { ved.timer.key_down(key, super) }
		.autocomplete { ved.key_insert(key, mod) }
		.debugger { ved.key_normal(key, mod) }
	}
	ved.gg.refresh_ui()
}

// key_normal 处理 Normal 模式下的按键
fn (mut ved Ved) key_normal(key gg.KeyCode, mod gg.Modifier) {
	super := mod.has(.super) || mod.has(.ctrl)
	shift := mod.has(.shift)
	// shift_and_super := int(mod) == 9 // 这种硬编码在不同平台可能不同，改为位运算判断
	shift_and_super := mod.has(.shift) && (mod.has(.super) || mod.has(.ctrl))
	mut view := ved.view
	ved.refresh = true
	if ved.prev_key == .r {
		return
	}
	if ved.prev_cmd == 'ci' {
		view.ci(key)
		return
	}
	match key {
		.enter {
			if super {
				width, height := get_screen_size()
				ved.win_width = width
				ved.win_height = height
			}
		}
		.period {
			if shift {
				ved.view.shift_right()
			} else {
				ved.dot()
			}
		}
		.comma {
			if shift {
				ved.view.shift_left()
			}
		}
		.slash {
			ved.search_query = ''
			ved.mode = .query
			ved.just_switched = true
			ved.search_dir = ''
			if shift {
				ved.query_type = .grep
			} else if super {
				ved.query_type = .search_in_folder
				ved.search_dir = os.dir(ved.view.path)
			} else {
				ved.query_type = .search
			}
		}
		.f5 {
			ved.run_file()
		}
		.minus {
			if shift_and_super {
				ved.increase_font(-1)
			} else if super {
				ved.get_git_diff_full()
			}
		}
		.equal {
			if shift {
				ved.prev_key = .equal
			} else if shift_and_super {
				ved.increase_font(1)
			}
		}
		.f12 {
			if shift {
				ved.open_blog()
			}
		}
		.apostrophe {
			if ved.prev_key == .apostrophe {
				ved.prev_key = gg.KeyCode.invalid
				ved.move_to_line(ved.prev_y)
				return
			}
		}
		._0 {
			if super {
				ved.query = ''
				ved.mode = .query
				ved.query_type = .task
				ved.just_switched = true
			} else {
				view.zero()
			}
		}
		._9 {
			if super {
				ved.query = '@'
				ved.mode = .query
				ved.query_type = .task
				ved.just_switched = true
			}
		}
		.a {
			if shift {
				view.save_snapshot()
				ved.view.shift_a()
				ved.prev_cmd = 'A'
				ved.set_insert()
			} else if super {
				ved.view.super_a(1)
				ved.prev_cmd = 'a'
			} else {
				view.save_snapshot()
				ved.view.l()
				ved.set_insert()
			}
		}
		.c {
			if super {
				ved.query = ''
				ved.mode = .query
				ved.query_type = .cam
				ved.just_switched = true
			} else if shift {
				ved.prev_insert = ved.view.shift_c()
				ved.set_insert()
			}
		}
		.d {
			if super {
				ved.prev_split()
				return
			}
			if ved.prev_key == .d {
				ved.view.dd()
				return
			} else if ved.prev_key == .g {
				ved.go_to_def()
			}
		}
		.e {
			if super {
				ved.next_split()
				return
			}
			if ved.prev_key == .c {
				view.ce()
			} else if ved.prev_key == .d {
				view.de()
			}
		}
		.i {
			if shift {
				view.save_snapshot()
				ved.view.shift_i()
				ved.set_insert()
				ved.prev_cmd = 'I'
			} else {
				if ved.prev_key == .c {
					ved.prev_cmd = 'ci'
				} else {
					view.save_snapshot()
					ved.set_insert()
				}
			}
		}
		.j {
			if shift {
				ved.view.join()
			} else if super {
				ved.mode = .query
				ved.query_type = .ctrlj
				ved.query = ''
				ved.just_switched = true
			} else {
				ved.view.j()
			}
		}
		.k {
			ved.view.k()
		}
		.n {
			if ved.mode == .debugger {
				ved.debugger.step_over()
			} else if shift {
				ved.search(.backward)
			} else {
				ved.search(.forward)
			}
		}
		.o {
			if shift_and_super {
				ved.mode = .query
				ved.query_type = .open_workspace
				ved.query = ''
			} else if super {
				ved.mode = .query
				ved.query_type = .open
				ved.query = ''
				ved.just_switched = true
				return
			} else if shift {
				view.save_snapshot()
				ved.view.shift_o()
				ved.set_insert()
			} else {
				view.save_snapshot()
				ved.view.o()
				ved.set_insert()
			}
		}
		.p {
			if shift_and_super {
				ved.mode = .query
				ved.query_type = .alert
				ved.query = 'Running git pull...'
				ved.just_switched = true
				spawn ved.git_pull()
				return
			} else if super {
				ved.mode = .query
				ved.query_type = .ctrlp
				ved.load_git_tree()
				ved.query = ''
				ved.just_switched = true
				return
			} else {
				view.p()
			}
		}
		.r {
			if shift_and_super {
				ved.query = ''
				ved.mode = .query
				ved.query_type = .run
				ved.just_switched = true
			} else if super {
				if view.redo_stack.len > 0 {
					view.redo()
				} else {
					view.reopen()
				}
			} else {
				ved.prev_key = .r
			}
		}
		.t {
			if super {
				ved.timer.load_tasks()
				ved.mode = .timer
			} else {
				view.tt()
			}
		}
		.u {
			if shift_and_super {
				ved.mode = .debugger
				ved.run_debugger(ved.view.breakpoints)
			} else if super {
				ved.key_u()
			} else {
				view.undo()
			}
		}
		.h {
			if shift {
				ved.view.shift_h()
			} else {
				ved.view.h()
			}
		}
		.l {
			if super {
				ved.just_switched = true
				ved.view.save_file()
			} else if shift {
				ved.view.move_to_page_bot()
			} else {
				ved.view.l()
			}
		}
		.g {
			if shift && !super {
				ved.view.shift_g()
			} else if super {
				ved.cb.copy(ved.view.path)
			} else {
				if ved.prev_key == .g {
					ved.prev_key = .invalid
					ved.view.gg()
				} else {
					ved.prev_key = .g
				}
			}
			return
		}
		.f {
			if super {
				ved.view.shift_f()
			}
		}
		.page_down {
			ved.view.shift_f()
		}
		.page_up {
			ved.view.shift_b()
		}
		.b {
			if shift_and_super {
				ved.view.add_breakpoint(ved.view.y)
			} else if super {
				ved.view.shift_b()
			} else {
				if ved.prev_key == .d {
					view.db(true)
				} else {
					ved.view.b()
				}
			}
		}
		.v {
			if super {
				ved.mode = .visual_block
				view.vstart = view.y
				view.vx = view.visual_x
				view.vend = view.y
			} else {
				ved.mode = .visual
				view.vstart = view.y
				view.vstart_x = view.x
				view.vend = view.y
				view.vend_x = view.x
			}
		}
		.w {
			if ved.prev_key == .c {
				view.cw()
			} else if ved.prev_key == .d {
				view.dw(true)
			} else {
				view.w()
			}
		}
		.x {
			if super {
				ved.view.super_a(-1)
				ved.prev_cmd = 'x'
			} else {
				ved.view.delete_char()
			}
		}
		.y {
			if ved.prev_key == .y {
				ved.view.yy()
			}
			if super {
				spawn ved.build_app2()
			}
		}
		.z {
			if ved.prev_key == .z {
				ved.view.zz()
			}
		}
		.right_bracket {
			if super {
				ved.open_workspace(ved.workspace_idx + 1)
			}
		}
		.left_bracket {
			if super {
				ved.open_workspace(ved.workspace_idx - 1)
			} else if ved.prev_key == .left_bracket {
				ved.go_to_fn_start()
			}
		}
		._8 {
			if shift {
				ved.star()
			}
		}
		._4 {
			if shift {
				view.dollar()
			}
		}
		._6 {
			if shift {
				view.shift_i()
			}
		}
		.left {
			if ved.view.x > 0 {
				ved.view.x--
			}
		}
		.right {
			ved.view.l()
		}
		.up {
			ved.view.k()
		}
		.down {
			ved.view.j()
		}
		._5 {
			if shift {
				ved.pct()
			}
		}
		else {}
	}
	if key != .r {
		ved.prev_key = key
	}
	if key == .q && super {
		ved.cq_in_a_row++
	} else {
		ved.cq_in_a_row = 0
	}
	if ved.cq_in_a_row == 2 {
		exit(0)
	}
}

// on_char 处理字符输入事件（通常用于非 macOS 系统或非插入模式）
@[manualfree]
fn on_char(code u32, mut ved Ved) {
	$if macos {
		if os.getenv('VED_TEST') == '' && (ved.mode == .insert || ved.mode == .autocomplete) {
			return
		}
	}
	mut buf := [5]u8{}
	s := unsafe { utf32_to_str_no_malloc(code, mut &buf[0]) }
	if ved.just_switched {
		ved.just_switched = false
		if s in ['i', 'a', 'o', 'I', 'A', 'O'] {
			return
		}
	}
	match ved.mode {
		.insert, .autocomplete {
			ved.char_insert(s)
		}
		.query {
			ved.gg_pos = -1
			ved.char_query(s)
		}
		.normal {
			if !ved.just_switched && ved.prev_key == .r {
				if s != 'r' {
					ved.view.r(s)
					ved.prev_key = gg.KeyCode.invalid
					ved.prev_cmd = 'r'
					ved.prev_insert = s.clone()
				}
				return
			}
			ved.prev_key_str = s
		}
		else {}
	}
}

// key_insert 处理插入模式下的按键
fn (mut ved Ved) key_insert(key gg.KeyCode, mod gg.Modifier) {
	super := mod.has(.super) || mod.has(.ctrl)
	match key {
		.backspace {
			ved.just_switched = true
			ved.view.backspace()
		}
		.enter {
			ved.view.enter()
		}
		.escape {
			ved.mode = .normal
		}
		.tab {
			line := ved.view.line()
			if line.ends_with('p ') {
				ved.view.insert_text("rintln('')")
				ved.view.x -= 2
			} else {
				ved.view.insert_text('\t')
			}
		}
		.left {
			if ved.view.x > 0 {
				ved.view.x--
			}
		}
		.right {
			ved.view.l()
		}
		.up {
			ved.view.k()
		}
		.down {
			ved.view.j()
		}
		else {}
	}
	if (key == .l || key == .s) && super {
		ved.view.save_file()
		ved.mode = .normal
		return
	}
	if super && key == .u {
		ved.mode = .normal
		ved.key_u()
		return
	}
	if super && key == .g {
		ved.view.insert_text('<code></code>')
		ved.view.x -= 7
	}
	if key == .n && super {
		ved.ctrl_n()
		return
	}
	if key == .v && super {
		ved.view.insert_text(ved.cb.paste())
		ved.just_switched = true
	}
}

// char_insert 插入单个字符
fn (mut ved Ved) char_insert(s string) {
	if int(s[0]) < 32 {
		return
	}
	ved.view.insert_text(s)
	ved.prev_insert += s
}

// key_visual 处理可视模式下的按键
fn (mut ved Ved) key_visual(key gg.KeyCode, mod gg.Modifier) {
	super := mod.has(.super) || mod.has(.ctrl)
	shift := mod.has(.shift)
	mut view := ved.view
	match key {
		.j {
			view.vend++
			if view.vend >= view.lines.len {
				view.vend = view.lines.len - 1
			}
			if view.vend >= view.from + view.page_height {
				view.from++
			}
			ved.view.j()
		}
		.k {
			if view.vend > 0 {
				view.vend--
			}
			ved.view.k()
		}
		.y {
			if ved.mode == .visual_block {
				view.y_visual_block()
			} else {
				view.y_visual()
			}
			ved.mode = .normal
		}
		.d {
			if ved.mode == .visual_block {
				view.d_visual_block()
			} else {
				view.d_visual()
			}
			ved.mode = .normal
		}
		.q {
			if ved.prev_key == .g {
				ved.view.gq()
			}
		}
		.period {
			if shift {
				ved.view.shift_right()
			}
		}
		.comma {
			if shift {
				ved.view.shift_left()
			}
		}
		._0 {
			if !super {
				view.zero()
				view.vend_x = view.x
			}
		}
		._4 {
			if shift {
				view.dollar()
				view.vend_x = view.x
			}
		}
		._6 {
			if shift {
				view.shift_i()
			}
		}
		.g {
			if shift {
				if view.lines.len > 0 {
					view.vend = view.lines.len - 1
					view.set_y(view.vend)
					view.from = if view.vend > view.page_height {
						view.vend - view.page_height + 1
					} else {
						0
					}
				}
				ved.prev_key = .invalid
				return
			} else if ved.prev_key == .g {
				view.vend = 0
				view.set_y(0)
				view.from = 0
				ved.prev_key = .invalid
				return
			}
		}
		.page_down, .f {
			if key == .f && !super {
				return
			}
			view.shift_f()
			view.vend = view.y
		}
		.page_up {
			view.shift_b()
			view.vend = view.y
		}
		.h {
			view.h()
			view.vend_x = view.x
		}
		.l {
			view.l()
			view.vend_x = view.x
		}
		.w {
			view.w()
			view.vend_x = view.x
		}
		.b {
			if super {
				view.shift_b()
				view.vend = view.y
			} else {
				view.b()
				view.vend_x = view.x
			}
		}
		else {}
	}

	if key != .r {
		ved.prev_key = key
	}
}
