// Copyright (c) 2019-2025 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by a GPL license
// that can be found in the LICENSE file.
module main

import os
import strings
import gg

// Snapshot 存储文件内容及其光标状态的快照
struct Snapshot {
	lines []string
	x     int
	y     int
}

// View 表示一个单独的编辑器窗格，包含打开文件的缓冲区状态。
// 包括文件路径、内容（行）、光标位置 (x, y)、滚动位置 (from) 和其他设置。
struct View {
mut:
	padding_left int     // 左侧行号区域的宽度
	from         int     // 当前屏幕显示的第一行行号
	from_x       int     // 当前屏幕显示的水平起始列 (水平滚动)
	x            int     // 当前光标的字节索引位置
	visual_x     int     // 目标视觉列位置（用于 j/k 移动时对齐）
	y            int     // 当前光标的行号索引
	prev_x       int     // 记录上一个 x 位置
	path         string  // 文件的完整磁盘路径
	short_path   string  // 用于显示的缩短后的路径
	prev_path    string  // 上一个打开的文件路径（用于 tt 命令切换）
	lines        []string // 文件的所有行内容
	undo_stack   []Snapshot // 撤销栈
	redo_stack   []Snapshot // 重做栈
	page_height  int     // 一页显示的行数
	vstart       int     // 可视模式选择的开始行
	vstart_x     int     // 可视模式选择的开始列 (字节索引)
	vend         int     // 可视模式选择的结束行
	vend_x       int     // 可视模式选择的结束列 (字节索引)
	changed      bool    // 文件是否已被修改
	error_y      int     // 错误行的高亮位置
	ved          &Ved = unsafe { nil } // 对主应用程序对象的引用
	prev_y       int     // 上一个 y 位置
	hash_comment bool    // 是否使用 # 进行注释
	hl_on        bool    // 语法高亮是否开启
	breakpoints  []int   // 存储断点行号
}

// new_view 创建并初始化一个新的 View 实例。
fn (ved &Ved) new_view() View {
	res := View{
		padding_left: 0
		path:         ''
		from:         0
		from_x:       0
		y:            0
		x:            0
		visual_x:     0
		page_height:  ved.page_height
		vstart:       -1
		vstart_x:     -1
		vend:         -1
		vend_x:       -1
		ved:          ved
		error_y:      -1
		prev_y:       -1
		undo_stack:   []Snapshot{}
		redo_stack:   []Snapshot{}
	}
	return res
}

// save_snapshot 将当前状态保存到撤销栈。
fn (mut view View) save_snapshot() {
	// 限制撤销栈大小为 100 步
	if view.undo_stack.len >= 100 {
		view.undo_stack.delete(0)
	}
	view.undo_stack << Snapshot{
		lines: view.lines.clone()
		x:     view.x
		y:     view.y
	}
	// 每次有新操作时，清空重做栈
	view.redo_stack = []Snapshot{}
}

// undo 执行撤销操作。
fn (mut view View) undo() {
	if view.undo_stack.len == 0 {
		return
	}
	// 将当前状态保存到重做栈
	view.redo_stack << Snapshot{
		lines: view.lines.clone()
		x:     view.x
		y:     view.y
	}
	// 从撤销栈恢复
	last := view.undo_stack.pop()
	view.lines = last.lines.clone()
	view.x = last.x
	view.y = last.y
	view.sync_visual_x()
	view.changed = true
}

// redo 执行重做操作。
fn (mut view View) redo() {
	if view.redo_stack.len == 0 {
		return
	}
	// 将当前状态存回撤销栈
	view.undo_stack << Snapshot{
		lines: view.lines.clone()
		x:     view.x
		y:     view.y
	}
	// 从重做栈恢复
	last := view.redo_stack.pop()
	view.lines = last.lines.clone()
	view.x = last.x
	view.y = last.y
	view.sync_visual_x()
	view.changed = true
}

// get_clean_words 从一行文本中提取单词列表。
fn get_clean_words(line string) []string {
	mut res := []string{}
	mut i := 0
	for i < line.len {
		for i < line.len && !is_alpha_underscore(int(line[i])) {
			i++
		}
		start2 := i
		for i < line.len && is_alpha_underscore(int(line[i])) {
			i++
		}
		word := line[start2..i]
		res << word
		i++
	}
	return res
}

// open_file 打开一个文件并将其内容加载到缓冲区。
fn (mut view View) open_file(path string, line_nr int) {
	if path == '' {
		return
	}
	if path.starts_with(view.ved.workspace + '/') {
		view.short_path = path[view.ved.workspace.len..]
		if view.short_path.starts_with('/') {
			view.short_path = view.short_path[1..]
		}
	} else {
		if path.starts_with(home_dir) {
			view.short_path = path.replace(home_dir, '~')
		} else {
			view.short_path = path
		}
	}
	mut ved := view.ved
	ved.set_current_syntax_idx(os.file_ext(path))
	if view.short_path !in ['out', ''] && view.short_path !in ved.open_paths[ved.workspace_idx] {
		if ved.open_paths[ved.workspace_idx].len == 0 {
			ved.open_paths[ved.workspace_idx] = []string{cap: ved.nr_splits}
		}
		ved.open_paths[ved.workspace_idx] << view.short_path
	}
	if path != view.path {
		view.ved.file_y_pos[view.path] = view.y
		view.prev_path = view.path
	}
	view.lines = os.read_lines(path) or { []string{} }
	if view.lines.len < 1000 {
		for line in view.lines {
			words := get_clean_words(line)
			for word in words {
				if word !in ved.words {
					ved.words << word
				}
			}
		}
	}
	if view.lines.len == 0 {
		view.lines << ''
	}
	view.path = path
	nr_lines := view.lines.len
	s := '${nr_lines}'
	view.padding_left = s.len * ved.cfg.char_width + 8
	view.ved.save_session()
	y := view.ved.file_y_pos[view.path]
	if y > 0 {
		view.set_y(y)
		if path != view.path {
			view.zz()
		}
	}
	if line_nr != 0 {
		view.move_to_line(line_nr)
	}
	view.l()
	view.h()
	view.sync_visual_x()
	view.hash_comment = !view.path.ends_with('.v')
	view.hl_on = !view.path.ends_with('.md') && !view.path.ends_with('.txt')
		&& view.path.contains('.')
	view.changed = false
	view.ved.gg.refresh_ui()
}

// reopen 重新加载当前文件。
fn (mut view View) reopen() {
	view.open_file(view.path, 0)
	view.changed = false
}

// save_file 将当前缓冲区内容写入磁盘。
fn (mut view View) save_file() {
	if view.path == '' {
		return
	}
	path := view.path
	view.ved.file_y_pos[view.path] = view.y
	mut file := os.create(path) or { panic('fail') }
	for line in view.lines {
		file.writeln(line.trim_right(' \t')) or { panic(err) }
	}
	file.close()
	spawn view.format_file()
	for mut v in view.ved.views {
		if v.path == view.path {
			v.reopen()
		}
	}
}

// format_file 异步运行代码格式化命令。
fn (mut view View) format_file() {
	view.ved.load_config2()
	if view.ved.cfg.disable_fmt {
		return
	}
	path := view.path
	fmt_cmd := view.ved.syntaxes[view.ved.current_syntax_idx].fmt_cmd.replace('<PATH>',
		os.quoted_path(path))
	if path.ends_with('.go') {
		os.system('goimports -w "${path}" ')
	} else if path.ends_with('.scss') {
		css := path.replace('.scss', '.css')
		os.system('sassc "${path}" > "${css}" ')
	} else if path.ends_with('.js') {
		os.system('prettier --use-tabs -w "${path}" ')
	} else if fmt_cmd != '' {
		os.system(fmt_cmd)
	}
	view.reopen()
	view.ved.get_git_diff()
	view.changed = false
}

// line 获取当前光标所在行的字符串。
fn (view &View) line() string {
	if view.y < 0 || view.y >= view.lines.len {
		return ''
	}
	return view.lines[view.y]
}

// uline 获取当前行的 rune 切片。
fn (view &View) uline() []rune {
	return view.line().runes()
}

// char 获取当前光标位置的字符（rune）。
fn (view &View) char() int {
	line := view.line()
	if line.len > 0 && view.x < line.len {
		return int(line[view.x])
	}
	return 0
}

// set_line 设置当前行的内容。
fn (mut view View) set_line(newline string) {
	if view.y < 0 {
		return
	}
	if view.y < view.lines.len {
		view.lines[view.y] = newline
	} else {
		view.lines << newline
	}
	view.changed = true
}

// set_y 设置光标的行位置索引。
fn (mut view View) set_y(new_y int) {
	view.y = new_y
	view.ved.update_cur_fn_name()
}

// sync_from_x 根据视觉列同步水平滚动偏移量。
fn (mut view View) sync_from_x() {
	if isnil(view.ved) {
		return
	}
	split_width := view.ved.split_width()
	// 计算视口宽度（以字符为单位）
	// 减去 padding_left 和左右侧的一些安全余量（比如 20 像素）
	content_width := split_width - view.padding_left - 20
	if content_width <= 0 {
		return
	}
	chars_per_page := content_width / view.ved.cfg.char_width
	if chars_per_page <= 0 {
		return
	}
	// 如果光标在视口左侧
	if view.visual_x < view.from_x {
		view.from_x = view.visual_x
	}
	// 如果光标在视口右侧
	else if view.visual_x >= view.from_x + chars_per_page {
		view.from_x = view.visual_x - chars_per_page + 1
	}
}

// sync_visual_x 根据字节索引同步视觉列位置。
fn (mut view View) sync_visual_x() {
	line := view.line()
	runes := line.runes()
	mut vx := 0
	mut byte_offset := 0
	for r in runes {
		if byte_offset >= view.x {
			break
		}
		if r == `\t` {
			vx += view.ved.cfg.tab_size
		} else {
			vx += rune_width(r)
		}
		byte_offset += r.length_in_bytes()
	}
	view.visual_x = vx
	view.sync_from_x()
}

// update_x_from_visual 根据目标视觉列位置更新字节索引。
fn (mut view View) update_x_from_visual() {
	line := view.line()
	runes := line.runes()
	mut vx := 0
	mut byte_offset := 0
	for r in runes {
		r_width := if r == `\t` { view.ved.cfg.tab_size } else { rune_width(r) }
		if vx + r_width > view.visual_x {
			break
		}
		vx += r_width
		byte_offset += r.length_in_bytes()
	}
	view.x = byte_offset
	view.sync_from_x()
}

// x_at_visual_pos 计算给定像素宽度下的最佳字节索引。
fn (view &View) x_at_visual_pos(visual_x int) int {
	line := view.line()
	runes := line.runes()
	mut cur_vx := 0
	mut byte_offset := 0
	for r in runes {
		r_width := if r == `\t` { view.ved.cfg.tab_size } else { rune_width(r) }
		if cur_vx + r_width / 2 >= visual_x {
			return byte_offset
		}
		cur_vx += r_width
		byte_offset += r.length_in_bytes()
	}
	return byte_offset
}

// j 光标向下移动一行。
fn (mut view View) j() {
	if view.lines.len == 0 {
		return
	}
	view.set_y(view.y + 1)
	if view.y >= view.lines.len {
		view.set_y(view.lines.len - 1)
		return
	}
	if view.y >= view.from + view.page_height {
		view.from++
	}
	view.update_x_from_visual()
}

// k 光标向上移动一行。
fn (mut view View) k() {
	if view.y >= view.lines.len {
		view.y = view.lines.len - 1
	}
	if view.y <= 0 {
		return
	}
	view.set_y(view.y - 1)
	if view.y < view.from && view.y >= 0 {
		view.from--
	}
	view.update_x_from_visual()
}

// shift_h 移动光标至页面顶部。
fn (mut view View) shift_h() {
	view.set_y(view.from)
}

// move_to_page_bot 移动光标至页面底部。
fn (mut view View) move_to_page_bot() {
	view.set_y(view.from + view.page_height - 1)
}

// l 光标向右移动一个字符。
fn (mut view View) l() {
	line := view.line()
	if view.x < line.len {
		mut len := 1
		if line[view.x] & 0x80 != 0 {
			len = utf8_char_len(line[view.x])
		}
		view.x += len
	}
	view.sync_visual_x()
}

// h 光标向左移动一个字符。
fn (mut view View) h() {
	if view.x > 0 {
		line := view.line()
		mut i := view.x - 1
		for i > 0 && (line[i] & 0xc0) == 0x80 {
			i--
		}
		view.x = i
	}
	line := view.line()
	if view.x > line.len {
		view.x = line.len
	}
	view.sync_visual_x()
}

// shift_g 跳转到文件末尾。
fn (mut view View) shift_g() {
	view.set_y(view.lines.len - 1)
	view.from = view.y - view.page_height + 1
	if view.from < 0 {
		view.from = 0
	}
}

// shift_a 行尾插入。
fn (mut view View) shift_a() {
	line := view.line()
	view.set_line('${line} ')
	view.x = view.line().len - 1
	view.sync_visual_x()
}

// shift_i 第一个非空字符插入。
fn (mut view View) shift_i() {
	view.x = 0
	for is_whitespace(u8(view.char())) {
		view.x++
	}
	view.sync_visual_x()
}

// gg 跳转到文件开头。
fn (mut view View) gg() {
	view.from = 0
	view.set_y(0)
}

// zero 跳转到行首位置 0。
fn (mut view View) zero() {
	view.x = 0
	view.sync_visual_x()
}

// dollar 跳转到行尾索引。
fn (mut view View) dollar() {
	line := view.line()
	view.x = line.len
	view.sync_visual_x()
}

// shift_f 向下滚动一页。
fn (mut view View) shift_f() {
	view.from += view.page_height
	if view.from >= view.lines.len {
		view.from = view.lines.len - 1
	}
	view.set_y(view.from)
}

// shift_b 向上滚动一页。
fn (mut view View) shift_b() {
	view.from -= view.page_height
	if view.from < 0 {
		view.from = 0
	}
	view.set_y(view.from)
}

// dd 删除当前行并复制。
fn (mut view View) dd() {
	if view.lines.len == 0 {
		return
	}
	view.save_snapshot()
	mut ved := view.ved
	ved.prev_key = gg.KeyCode.invalid
	ved.prev_cmd = 'dd'
	ved.ylines = []
	ved.ylines << view.line()
	view.lines.delete(view.y)
	if view.y >= view.lines.len && view.lines.len > 0 {
		view.y = view.lines.len - 1
	}
	line := view.line()
	if view.x > line.len {
		view.x = line.len
	}
	view.h()
	view.sync_visual_x()
	view.changed = true
}

// shift_right 向右缩进。
fn (mut view View) shift_right() {
	view.save_snapshot()
	if view.vstart == -1 {
		view.set_line('\t${view.line()}')
		return
	}
	for i := view.vstart; i <= view.vend; i++ {
		line := view.lines[i]
		view.lines[i] = '\t${line}'
	}
}

// shift_left 向左缩进。
fn (mut view View) shift_left() {
	view.save_snapshot()
	if view.vstart == -1 {
		line := view.line()
		if !line.starts_with('\t') {
			return
		}
		view.set_line(line[1..])
		return
	}
	for i := view.vstart; i <= view.vend; i++ {
		line := view.lines[i]
		if !line.starts_with('\t') {
			continue
		}
		view.lines[i] = line[1..]
	}
}

// delete_char 删除光标下的字符。
fn (mut v View) delete_char() {
	v.save_snapshot()
	line := v.line()
	if line.len < 1 || v.x >= line.len {
		return
	}
	char_len := utf8_char_len(line[v.x])
	mut new_line := line[..v.x]
	if v.x + char_len < line.len {
		new_line += line[v.x + char_len..]
	}
	v.set_line(new_line)
	if v.x >= new_line.len && new_line.len > 0 {
		mut i := new_line.len - 1
		for i > 0 && (new_line[i] & 0xc0) == 0x80 {
			i--
		}
		v.x = i
	}
}

// shift_c 删除光标到行尾的内容并进入插入模式。
fn (mut view View) shift_c() string {
	view.save_snapshot()
	line := view.line()
	s := line[..view.x]
	deleted := line[view.x..]
	view.set_line('${s} ')
	view.x = s.len
	return deleted
}

// insert_text 在光标处插入文本。
fn (mut view View) insert_text(s string) {
	line := view.line()
	if line.len == 0 {
		view.set_line(s)
		view.x = s.len
	} else {
		if view.x > line.len {
			view.x = line.len
		}
		left := line[..view.x]
		right := line[view.x..]
		res := '${left}${s}${right}'
		view.set_line(res)
		view.x += s.len
	}
	view.sync_visual_x()
}

// backspace 处理退格。
fn (mut view View) backspace() {
	if view.x == 0 {
		// 如果允许向上退格且不是第一行
		if view.y > 0 {
			view.save_snapshot()
			// 获取当前行剩下的内容
			current_line_text := view.lines[view.y]
			// 移除当前行
			view.lines.delete(view.y)
			// 移动到上一行
			view.y--
			// 记录合并前上一行的长度作为新的 x 位置
			prev_line_len := view.lines[view.y].len
			// 将内容合并到上一行
			view.lines[view.y] += current_line_text
			view.x = prev_line_len
			
			view.sync_visual_x()
			view.changed = true
		}
		return
	}
	line := view.line()
	mut i := view.x - 1
	for i > 0 && (line[i] & 0xc0) == 0x80 {
		i--
	}
	left := line[..i]
	mut right := ''
	if view.x < line.len {
		right = line[view.x..]
	}
	view.set_line('${left}${right}')
	view.x = i
	if view.ved.prev_insert.len > 0 {
		view.ved.prev_insert = view.ved.prev_insert[..view.ved.prev_insert.len - 1]
	}
	view.sync_visual_x()
}

// yy 复制当前行。
fn (mut view View) yy() {
	view.ved.ylines = [view.line()]
}

// p 粘贴。
fn (mut view View) p() {
	if view.ved.ylines.len == 0 { return }
	view.save_snapshot()
	for line in view.ved.ylines {
		view.o()
		view.set_line(line)
	}
}

// shift_o 在上方开启新行。
fn (mut view View) shift_o() {
	view.o_generic(0)
}

// o 在下方开启新行。
fn (mut view View) o() {
	view.o_generic(1)
}

fn (mut view View) o_generic(delta int) {
	view.y += delta
	prev_line := if view.lines.len == 0 || view.y == 0 {
		''
	} else {
		prev_idx := view.y - 1
		if prev_idx >= 0 && prev_idx < view.lines.len {
			view.lines[prev_idx]
		} else {
			''
		}
	}
	nr_spaces, nr_tabs := nr_spaces_and_tabs_in_line(prev_line)
	mut new_line := strings.repeat(`\t`, nr_tabs) + strings.repeat(` `, nr_spaces)
	if prev_line.ends_with('{') || prev_line.ends_with('{ ') {
		new_line += '\t '
	} else if !new_line.ends_with(' ') {
		new_line += ' '
	}
	view.x = new_line.len - 1
	if view.y >= view.lines.len {
		view.lines << new_line
	} else {
		view.lines.insert(view.y, new_line)
	}
	view.changed = true
	view.sync_visual_x()
}

// enter 回车换行。
fn (mut view View) enter() {
	pos := view.x
	line := view.line()
	if pos >= line.len - 1 && line != '' && line != ' ' {
		if line.ends_with('{ ') {
			view.o()
			view.x--
			view.insert_text('}')
			view.y--
			view.o()
		} else {
			view.o()
		}
		return
	}
	uline := line.runes()
	mut right := ''
	if pos < uline.len {
		right = uline[pos..].string()
	}
	left := uline[..pos].string()
	view.set_line(left)
	view.o()
	view.set_line(right)
	view.x = 0
	view.sync_visual_x()
}

// join 合并行。
fn (mut view View) join() {
	if view.y == view.lines.len - 1 {
		return
	}
	view.save_snapshot()
	line := view.line()
	second_line := view.lines[view.y + 1]
	joined := line + second_line
	view.set_line(joined)
	view.y++
	view.dd()
	view.y--
}

// y_visual 复制可视选择范围。
fn (mut v View) y_visual() {
	if v.vstart == -1 {
		return
	}
	mut ylines := []string{}
	mut v_from_y := v.vstart
	mut v_from_x := v.vstart_x
	mut v_to_y := v.vend
	mut v_to_x := v.vend_x

	if v_from_y > v_to_y || (v_from_y == v_to_y && v_from_x > v_to_x) {
		v_from_y, v_to_y = v_to_y, v_from_y
		v_from_x, v_to_x = v_to_x, v_from_x
	}

	if v_from_y == v_to_y {
		line := v.lines[v_from_y]
		if v_from_x < line.len {
			end_x := if v_to_x > line.len { line.len } else { v_to_x }
			ylines << line[v_from_x..end_x]
		} else {
			ylines << ''
		}
	} else {
		// 起始行
		first_line := v.lines[v_from_y]
		ylines << if v_from_x < first_line.len { first_line[v_from_x..] } else { '' }
		// 中间行
		for i := v_from_y + 1; i < v_to_y; i++ {
			ylines << v.lines[i]
		}
		// 结束行
		last_line := v.lines[v_to_y]
		end_x := if v_to_x > last_line.len { last_line.len } else { v_to_x }
		ylines << if v_to_x > 0 { last_line[..end_x] } else { '' }
	}

	mut ved := v.ved
	ved.ylines = ylines
	ved.cb.copy(ylines.join('\n'))
	
	v.vstart = -1
	v.vstart_x = -1
	v.vend = -1
	v.vend_x = -1
}

// d_visual 删除可视选择范围。
fn (mut v View) d_visual() {
	if v.vstart == -1 {
		return
	}
	v.save_snapshot()
	
	mut v_from_y := v.vstart
	mut v_from_x := v.vstart_x
	mut v_to_y := v.vend
	mut v_to_x := v.vend_x

	if v_from_y > v_to_y || (v_from_y == v_to_y && v_from_x > v_to_x) {
		v_from_y, v_to_y = v_to_y, v_from_y
		v_from_x, v_to_x = v_to_x, v_from_x
	}

	v.y_visual() // 这也会把选中内容存入剪贴板并重置 vstart 等，所以我们需要先保留坐标

	if v_from_y == v_to_y {
		line := v.lines[v_from_y]
		prefix := line[..v_from_x]
		suffix := if v_to_x < line.len { line[v_to_x..] } else { '' }
		v.lines[v_from_y] = prefix + suffix
		v.x = v_from_x
		v.y = v_from_y
	} else {
		prefix := v.lines[v_from_y][..v_from_x]
		last_line := v.lines[v_to_y]
		suffix := if v_to_x < last_line.len { last_line[v_to_x..] } else { '' }
		
		v.lines[v_from_y] = prefix + suffix
		
		// 删除中间行和结束行
		for i := 0; i < v_to_y - v_from_y; i++ {
			v.lines.delete(v_from_y + 1)
		}
		v.x = v_from_x
		v.y = v_from_y
	}
	v.sync_visual_x()
}

// cw 修改单词。
fn (mut view View) cw() {
	mut ved := view.ved
	ved.prev_insert = ''
	view.dw(false)
	ved.prev_cmd = 'cw'
	ved.mode = .insert
	ved.just_switched = true
}

// dw 删除单词。
fn (mut view View) dw(del_whitespace bool) {
	view.save_snapshot()
	mut ved := view.ved
	typ := is_alpha(u8(view.char()))
	for {
		line := view.line()
		if view.x < 0 || view.x >= line.len - 1 {
			break
		}
		if typ == is_alpha(u8(view.char())) {
			view.delete_char()
		} else {
			break
		}
	}
	if del_whitespace {
		for is_whitespace(u8(view.char())) {
			line := view.line()
			if view.x < 0 || view.x >= line.len {
				break
			}
			view.delete_char()
		}
	}
	ved.prev_cmd = 'dw'
}

// db 向后删除单词。
fn (mut view View) db(del_whitespace bool) {
	view.save_snapshot()
	mut ved := view.ved
	typ := is_alpha(u8(view.char()))
	for {
		line := view.line()
		if view.x < 0 || view.x >= line.len - 1 {
			break
		}
		view.x--
		if typ == is_alpha_underscore(u8(view.char())) {
			view.delete_char()
		} else {
			break
		}
	}
	view.x++
	ved.prev_cmd = 'db'
}

// ce 修改当前单词。
fn (mut view View) ce() {
	mut ved := view.ved
	view.de()
	ved.prev_cmd = 'ce'
	view.ved.set_insert()
}

// w 移动到下一单词。
fn (mut view View) w() {
	line := view.line()
	if view.x >= line.len { return }
	
	runes := line.runes()
	// 找到当前光标所在的 rune 索引
	mut cur_idx := 0
	mut byte_off := 0
	for i, r in runes {
		if byte_off >= view.x {
			cur_idx = i
			break
		}
		byte_off += r.length_in_bytes()
	}

	if cur_idx >= runes.len { return }
	
	start_kind := get_char_kind(runes[cur_idx])
	
	// 逻辑：
	// 1. 如果当前是中文，移动一个字符。
	// 2. 如果是 Word 或 Punct，移动到该类结束。
	if start_kind == .cjk {
		cur_idx++
	} else {
		for cur_idx < runes.len && get_char_kind(runes[cur_idx]) == start_kind {
			cur_idx++
		}
	}
	
	// 3. 跳过随后的空格
	for cur_idx < runes.len && get_char_kind(runes[cur_idx]) == .space {
		cur_idx++
	}
	
	// 将 rune 索引转回字节偏移
	mut target_byte_off := 0
	for i in 0..cur_idx {
		target_byte_off += runes[i].length_in_bytes()
	}
	view.x = target_byte_off
	view.sync_visual_x()
}

// b 移动到上一个单词。
fn (mut view View) b() {
	if view.x <= 0 { return }
	line := view.line()
	runes := line.runes()
	
	// 找到当前光标所在的 rune 索引
	mut cur_idx := 0
	mut byte_off := 0
	for i, r in runes {
		if byte_off >= view.x {
			cur_idx = i
			break
		}
		byte_off += r.length_in_bytes()
	}
	if cur_idx == 0 { view.x = 0; return }

	// 1. 先跳过前面的空格
	mut idx := cur_idx - 1
	for idx > 0 && get_char_kind(runes[idx]) == .space {
		idx--
	}
	
	// 2. 确定当前词的分类
	kind := get_char_kind(runes[idx])
	if kind == .cjk {
		// 中文只跳一个
	} else {
		// Word 或 Punct 跳到开始
		for idx > 0 && get_char_kind(runes[idx - 1]) == kind {
			idx--
		}
	}
	
	// 将 rune 索引转回字节偏移
	mut target_byte_off := 0
	for i in 0..idx {
		target_byte_off += runes[i].length_in_bytes()
	}
	view.x = target_byte_off
	view.sync_visual_x()
}

// de 删除到单词末尾。
fn (mut view View) de() {
	view.save_snapshot()
	line := view.line()
	if view.x >= line.len { return }
	
	runes := line.runes()
	mut cur_idx := 0
	mut byte_off := 0
	for i, r in runes {
		if byte_off >= view.x {
			cur_idx = i
			break
		}
		byte_off += r.length_in_bytes()
	}
	
	start_kind := get_char_kind(runes[cur_idx])
	mut end_idx := cur_idx
	if start_kind == .cjk {
		end_idx = cur_idx + 1
	} else {
		for end_idx < runes.len && get_char_kind(runes[end_idx]) == start_kind {
			end_idx++
		}
	}
	
	// 计算删除的字节范围
	mut end_byte_off := 0
	for i in 0..end_idx {
		end_byte_off += runes[i].length_in_bytes()
	}
	
	new_line := line[..view.x] + line[end_byte_off..]
	view.set_line(new_line)
	view.ved.prev_cmd = 'de'
}

// ci 快速修改成对符号内的内容。
fn (mut view View) ci(key gg.KeyCode) {
	mut ved := view.ved
	line := view.line()
	defer {
		ved.prev_cmd = ''
	}
	match key {
		.apostrophe {
			if !line.contains("'" ) {
				return
			}
			mut start := view.x
			for line[start] != `\'` {
				start--
			}
			mut end := view.x
			for line[end] != `\'` {
				end++
			}
			view.set_line(line[..start + 1] + line[end..])
			view.x = start + 1
			view.ved.set_insert()
		}
		._9 {}
		else {}
	}
}

// zz 居中显示当前行。
fn (mut view View) zz() {
	view.from = view.y - view.ved.page_height / 2
	if view.from < 0 {
		view.from = 0
	}
}

// r 替换字符。
fn (mut view View) r(s string) {
	view.save_snapshot()
	view.delete_char()
	view.insert_text(s)
	view.x--
}

// tt 切换回上一文件。
fn (mut view View) tt() {
	if view.prev_path == '' {
		return
	}
	mut ved := view.ved
	ved.prev_key = .invalid
	view.open_file(view.prev_path, 0)
}

// move_to_line 移动到特定行。
fn (mut view View) move_to_line(line int) {
	view.prev_y = view.y
	view.from = line
	view.set_y(line)
	view.zz()
}

// CharKind 定义字符的分类
enum CharKind {
	word   // 字母、数字、下划线
	cjk    // 中日韩字符
	punct  // 标点符号
	space  // 空格、制表符
}

// get_char_kind 返回特定字符的分类
fn get_char_kind(r rune) CharKind {
	if r == ` ` || r == `\t` || r == `\n` || r == `\r` {
		return .space
	}
	// ASCII 单词字符
	if (r >= `a` && r <= `z`) || (r >= `A` && r <= `Z`) || (r >= `0` && r <= `9`) || r == `_` || r == `#` || r == `$` {
		return .word
	}
	// CJK 范围判断
	if (int(r) >= 0x4E00 && int(r) <= 0x9FFF) || (int(r) >= 0x3040 && int(r) <= 0x30FF) || (int(r) >= 0xFF00 && int(r) <= 0xFFEF) {
		return .cjk
	}
	return .punct
}

// super_a 加减行首第一个数字。
fn (mut view View) super_a(diff int) {
	line := view.line()
	mut num_start_pos := -1
	for i, r in line {
		if r >= `0` && r <= `9` {
			num_start_pos = i
			break
		}
	}
	if num_start_pos == -1 {
		return
	}
	s := line[num_start_pos..]
	vals := s.fields()
	number := vals[0].int()
	new_line := line.replace_once(number.str(), (number + diff).str())
	view.set_line(new_line)
}

// is_alpha 是否为字母数字。
fn is_alpha(r u8) bool {
	return (r >= `a` && r <= `z`) || (r >= `A` && r <= `Z`) || (r >= `0` && r <= `9`)
}

// is_whitespace 是否为空格或制表符。
fn is_whitespace(r u8) bool {
	return r == ` ` || r == `\t`
}

// is_alpha_underscore 是否为合法标识符字符。
fn is_alpha_underscore(r int) bool {
	return is_alpha(u8(r)) || u8(r) == `_` || u8(r) == `#` || u8(r) == `$`
}

// break_text 文字折行。
fn break_text(s string, max int) []string {
	mut lines := []string{}
	mut start := 0
	for i := 0; i < s.len; i++ {
		if i == s.len - 1 {
			lines << s[start..i + 1]
			break
		}
		if i - start >= max {
			lines << s[start..i]
			start = i
		}
	}
	return lines
}