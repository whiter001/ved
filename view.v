// Copyright (c) 2019-2025 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by a GPL license
// that can be found in the LICENSE file.
module main // 主模块

import os // 操作系统相关功能
import strings // 字符串处理
import gg // 图形库

// View 表示单个编辑器窗格或“视图”，包含打开文件缓冲区的状态。
// 这包括文件路径、内容（行）、光标位置（x, y）、
// 滚动位置（from）和其他视图特定设置。
struct View {
mut:
	padding_left int     // 左侧填充
	from         int     // 起始行
	x            int     // 光标 x 位置
	y            int     // 光标 y 位置
	prev_x       int     // 上一个 x 位置
	path         string  // 文件路径
	short_path   string  // 短路径
	prev_path    string  // 上一个路径，用于 tt
	lines        []string // 文件行
	page_height  int     // 页面高度
	vstart       int     // 可视开始
	vend         int     // 可视结束
	changed      bool    // 是否已更改
	error_y      int     // 错误行
	ved          &Ved = unsafe { nil } // Ved 引用
	prev_y       int     // 上一个 y 位置
	hash_comment bool    // 是否哈希注释
	hl_on        bool    // 是否高亮开启
	breakpoints  []int   // 断点行号
}

// 创建并初始化一个新的 View 实例
fn (ved &Ved) new_view() View {
	res := View{
		padding_left: 0      // 左侧填充
		path:         ''     // 路径
		from:         0      // 起始行
		y:            0      // y 位置
		x:            0      // x 位置
		prev_x:       0      // 上一个 x
		page_height:  ved.page_height // 页面高度
		vstart:       -1     // 可视开始
		vend:         -1     // 可视结束
		ved:          ved    // Ved 引用
		error_y:      -1     // 错误行
		prev_y:       -1     // 上一个 y
	}
	return res // 返回结果
}

// 从行中提取单词列表。
// “单词”被认为是字母数字字符和下划线的连续序列。
fn get_clean_words(line string) []string {
	mut res := []string{} // 结果列表
	mut i := 0 // 索引
	for i < line.len { // 遍历行
		// 跳过坏的第一个
		for i < line.len && !is_alpha_underscore(int(line[i])) { // 跳过非字母数字
			i++
		}
		// 读取所有好的
		start2 := i // 开始位置
		for i < line.len && is_alpha_underscore(int(line[i])) { // 读取单词
			i++
		}
		// 单词结束，保存它
		word := line[start2..i] // 提取单词
		res << word // 添加到结果
		i++ // 继续
	}
	return res // 返回结果
}

// 打开给定路径的文件，将其内容加载到视图的缓冲区中，
// 并可选地将光标移动到 line_nr。它还更新编辑器的状态，
// 如打开文件列表和语法高亮设置。
fn (mut view View) open_file(path string, line_nr int) {
	println('open file "${path}"') // 打印打开文件信息
	if path == '' { // 如果路径为空
		return // 返回
	}
	// 此路径在当前工作区中？修剪它。 /code/v/file.v => file.v
	if path.starts_with(view.ved.workspace + '/') { // 如果以工作区开头
		view.short_path = path[view.ved.workspace.len..] // 设置短路径
		if view.short_path.starts_with('/') { // 如果以 / 开头
			view.short_path = view.short_path[1..] // 移除
		}
	} else {
		// 优化空间，用 ~ 替换 /Users/username
		if path.starts_with(home_dir) { // 如果以主目录开头
			view.short_path = path.replace(home_dir, '~') // 替换为 ~
		} else {
			view.short_path = path // 否则直接设置
		}
	}
	mut ved := view.ved
	ved.set_current_syntax_idx(os.file_ext(path))
	// if os.exists(view.short_path) &&
	if view.short_path !in ['out', ''] && view.short_path !in ved.open_paths[ved.workspace_idx] {
		if ved.open_paths[ved.workspace_idx].len == 0 {
			ved.open_paths[ved.workspace_idx] = []string{cap: ved.nr_splits}
		}
		ved.open_paths[ved.workspace_idx] << view.short_path
	}
	if path != view.path {
		// Save cursor pos (Y)
		view.ved.file_y_pos[view.path] = view.y
		view.prev_path = view.path
	}
	/*
	mut lines := []string{}
	if rlines := os.read_lines(path) {
		lines = rlines
	}
	view.lines = lines
	*/
	view.lines = os.read_lines(path) or { []string{} }
	// get words map
	if view.lines.len < 1000 {
		println('getting words')
		// ticks := glfw.get_time()
		for line in view.lines {
			// words := line.split(' ')
			words := get_clean_words(line)
			for word in words {
				// clean_word := get_clean_word(word)
				// if clean_word == '' {
				// continue
				// }
				if word !in ved.words {
					ved.words << word
				}
			}
		}
		// took := glfw.get_time() - ticks
	}
	// Empty file, handle it
	if view.lines.len == 0 {
		view.lines << ''
	}
	view.path = path
	// view.short_path = path.replace(view.ved.workspace, '')
	// Calc padding_left
	nr_lines := view.lines.len
	s := '${nr_lines}'
	view.padding_left = s.len * ved.cfg.char_width + 8
	view.ved.save_session()
	// Go to old y for this file
	y := view.ved.file_y_pos[view.path]
	if y > 0 {
		view.set_y(y)
		if path != view.path {
			view.zz()
		}
	}
	// Call zz() if it's out of bounds
	if view.from > view.y || view.from + view.ved.page_height < view.y {
		// view.zz()
	}

	if line_nr != 0 {
		view.move_to_line(line_nr)
	}

	view.l()
	view.h() // so that cursor pos is correct and doesn't point to no longer existing text

	view.hash_comment = !view.path.ends_with('.v')
	view.hl_on = !view.path.ends_with('.md') && !view.path.ends_with('.txt')
		&& view.path.contains('.')
	view.changed = false
	view.ved.gg.refresh_ui()
	// go view.ved.write_changes_in_file_every_5s()
}

// reopen reloads the content of the file currently associated with the view from disk.
// This is useful for discarding changes or updating the view after external modifications.
// 重新加载视图关联文件的磁盘内容。
// 这对于丢弃更改或在外部修改后更新视图很有用。
fn (mut view View) reopen() {
	view.open_file(view.path, 0) // 重新打开文件
	view.changed = false // 设置未更改
}

// save_file saves the current content of the view's buffer to its associated file on disk.
// It then triggers an asynchronous file formatting process.
// 将视图缓冲区的当前内容保存到其关联的文件磁盘上。
// 然后触发异步文件格式化过程。
fn (mut view View) save_file() {
	if view.path == '' { // 如果路径为空
		return // 返回
	}
	path := view.path // 获取路径
	view.ved.file_y_pos[view.path] = view.y // 保存 y 位置
	println('saving file "${path}"') // 打印保存信息
	println('lines.len=${view.lines.len}') // 打印行数
	// line0 := view.lines[0]
	// println('line[0].len=$line0.len')
	mut file := os.create(path) or { panic('fail') } // 创建文件
	for line in view.lines { // 遍历行
		file.writeln(line.trim_right(' \t')) or { panic(err) } // 写入行，修剪右侧空格
	}
	file.close() // 关闭文件
	spawn view.format_file() // 异步格式化文件
	// If another split has the same file open, update it
	// 如果另一个分屏打开了同一文件，更新它
	for mut v in view.ved.views { // 遍历视图
		if v.path == view.path { // 如果路径相同
			v.reopen() // 重新打开
		}
	}
}

// format_file asynchronously runs an external formatting command (like `v fmt`, `goimports`, `prettier`)
// on the view's file. After formatting, it reloads the file to reflect the changes.
// 异步地在视图的文件上运行外部格式化命令（如 `v fmt`、`goimports`、`prettier`）。
// 格式化后，重新加载文件以反映更改。
fn (mut view View) format_file() {
	view.ved.load_config2() // 加载配置
	if view.ved.cfg.disable_fmt { // 如果禁用格式化
		return // 返回
	}
	path := view.path // 获取路径
	// Run formatters
	// 运行格式化器
	fmt_cmd := view.ved.syntaxes[view.ved.current_syntax_idx].fmt_cmd.replace('<PATH>', // 获取格式化命令
		os.quoted_path(path))
	if path.ends_with('.go') { // 如果是 Go 文件
		println('running goimports') // 打印运行 goimports
		os.system('goimports -w "${path}"') // 运行 goimports
	} else if path.ends_with('.scss') { // 如果是 SCSS 文件
		css := path.replace('.scss', '.css') // 替换为 CSS
		os.system('sassc "${path}" > "${css}"') // 运行 sassc
	} else if path.ends_with('.js') { // 如果是 JS 文件
		os.system('prettier --use-tabs -w "${path}"') // 运行 prettier
	} else if fmt_cmd != '' { // 如果有格式化命令
		os.system(fmt_cmd) // 运行命令
	}
	view.reopen() // 重新打开
	// update git diff
	// 更新 git diff
	view.ved.get_git_diff() // 获取 git diff
	view.changed = false // 设置未更改
	// println('end of save file()')
	// println('_lines.len=$view.lines.len')
	// line0_ := view.lines[0]
	// println('_line[0].len=$line0_.len')
}

// line returns the content of the current line (at cursor position `y`) as a string.
// 返回当前行（光标位置 `y`）的内容作为字符串。
fn (view &View) line() string {
	if view.y < 0 || view.y >= view.lines.len { // 如果 y 超出范围
		return '' // 返回空
	}
	return view.lines[view.y] // 返回行
}

// uline returns the content of the current line as a slice of runes, suitable for multi-byte character manipulation.
// 返回当前行作为符文切片，适合多字节字符操作。
fn (view &View) uline() []rune {
	return view.line().runes() // 返回符文
}

// char returns the character (as an integer rune) at the current cursor position (`x`).
// 返回当前光标位置（`x`）的字符（作为整数符文）。
fn (view &View) char() int {
	line := view.line() // 获取行
	if line.len > 0 && view.x < line.len { // 如果位置有效
		return int(line[view.x]) // 返回字符
	}
	return 0 // 返回 0
}

// set_line replaces the content of the current line with `newline`.
// 用 `newline` 替换当前行的内容。
fn (mut view View) set_line(newline string) {
	if view.y < 0 { // 基本健全性检查
		return // 返回
	}
	if view.y < view.lines.len { // 检查索引是否在当前边界内
		view.lines[view.y] = newline // 设置行
	} else if view.y == view.lines.len { // 检查索引是否正好在末尾之后
		view.lines << newline // 添加行
	} else { // 索引太大
		// Optionally, append anyway or just return to prevent further issues
		// 可选地，仍然追加或只是返回以防止进一步问题
		view.lines << newline // 作为后备追加？或只是返回？追加似乎更安全用于粘贴。
	}
	view.changed = true // 设置已更改
}

// set_y sets the vertical position (line number) of the cursor.
// 设置光标的垂直位置（行号）。
fn (mut view View) set_y(new_y int) {
	view.y = new_y // 设置 y
	view.ved.update_cur_fn_name() // 更新当前函数名
}

// j moves the cursor down one line, handling scrolling and maintaining horizontal position. (Vim: `j`)
// 将光标向下移动一行，处理滚动并保持水平位置。（Vim: `j`）
fn (mut view View) j() {
	if view.lines.len == 0 { // 如果行数为 0
		return // 返回
	}
	line0 := view.line() // 获取当前行
	view.set_y(view.y + 1) // 设置 y + 1
	// Reached end
	// 到达末尾
	if view.y >= view.lines.len { // 如果超出
		view.set_y(view.lines.len - 1) // 设置为最后一行
		return // 返回
	}
	// Scroll
	if view.y >= view.from + view.page_height {
		view.from++
	}
	// Correct x if there are tabs on the next line
	_, nr_tabs1 := nr_spaces_and_tabs_in_line(line0)
	line := view.line()
	_, nr_tabs2 := nr_spaces_and_tabs_in_line(line)
	// println('tabs1,2=${nr_tabs1},${nr_tabs2}')
	// println(view.ved.cfg.tab_size)
	if nr_tabs2 > nr_tabs1 {
		view.x -= (nr_tabs2 - nr_tabs1) * view.ved.cfg.tab_size - 1
	}
	// Line below is shorter, move to the end of it
	if view.x > line.len {
		view.prev_x = view.x
		view.x = line.len
	}
	if view.x < 0 {
		view.x = 0
	}
}

// k moves the cursor up one line, handling scrolling and maintaining horizontal position. (Vim: `k`)
// 将光标向上移动一行，处理滚动并保持水平位置。（Vim: `k`）
fn (mut view View) k() {
	if view.y >= view.lines.len { // 如果 y 超出
		view.y = view.lines.len - 1 // 设置为最后一行
	}
	if view.y <= 0 { // 如果 y <= 0
		return // 返回
	}
	line0 := view.line() // 获取当前行
	view.set_y(view.y - 1) // 设置 y - 1
	// Scroll
	// 滚动
	if view.y < view.from && view.y >= 0 { // 如果需要向上滚动
		view.from-- // 减少 from
	}
	// Correct x if there are tabs on the prev line
	// 如果上一行有制表符，修正 x
	_, nr_tabs1 := nr_spaces_and_tabs_in_line(line0) // 获取当前行制表符数
	line := view.line() // 获取新行
	_, nr_tabs2 := nr_spaces_and_tabs_in_line(line) // 获取新行制表符数
	// println('tabs1,2=${nr_tabs1},${nr_tabs2}')
	// println(view.ved.cfg.tab_size)
	if nr_tabs2 < nr_tabs1 { // 如果新行制表符少
		view.x -= (nr_tabs1 - nr_tabs2) * view.ved.cfg.tab_size - 1 // 调整 x
		if view.x < 0 { // 如果 x < 0
			view.x = 0 // 设置为 0
		}
	}
	// Line above is shorter, move to the end of it
	// 如果上一行较短，移动到末尾
	if view.x > line.len { // 如果 x 超出
		view.prev_x = view.x // 保存 prev_x
		view.x = line.len // 设置为行长
		if view.x < 0 { // 如果 x < 0
			view.x = 0 // 设置为 0
		}
	}
}

// shift_h moves the cursor to the first visible line on the screen (the top of the current page). (Vim: `H`)
// 将光标移动到屏幕上的第一可见行（当前页面的顶部）。（Vim: `H`）
fn (mut view View) shift_h() {
	view.set_y(view.from) // 设置 y 为 from
}

// move_to_page_bot moves the cursor to the last visible line on the screen (the bottom of the current page). (Vim: `L`)
// 将光标移动到屏幕上的最后可见行（当前页面的底部）。（Vim: `L`）
fn (mut view View) move_to_page_bot() {
	view.set_y(view.from + view.page_height - 1) // 设置 y 为 from + page_height - 1
}

// l moves the cursor one character to the right. (Vim: `l`)
// 将光标向右移动一个字符。（Vim: `l`）
fn (mut view View) l() {
	line := view.line() // 获取行
	if view.x < line.len { // 如果 x < 行长
		// Move to the next UTF-8 character boundary
		// 移动到下一个 UTF-8 字符边界
		mut len := 1 // 默认长度 1
		if line[view.x] & 0x80 != 0 { // 如果是多字节字符
			len = utf8_char_len(line[view.x]) // 获取字符长度
		}
		view.x += len // 增加 x
	}
}

// h moves the cursor one character to the left. (Vim: `h`)
// 将光标向左移动一个字符。（Vim: `h`）
fn (mut view View) h() {
	if view.x > 0 { // 如果 x > 0
		line := view.line() // 获取行
		// Move to the previous UTF-8 character boundary
		// 移动到上一个 UTF-8 字符边界
		mut i := view.x - 1 // 从 x-1 开始
		for i > 0 && (line[i] & 0xc0) == 0x80 { // 找到字符开始
			i-- // 减少 i
		}
		view.x = i // 设置 x
	}
	line := view.line() // 获取行
	// Cursor is outside the line, move it to the end of it
	// 光标在行外，移动到行末
	if view.x > line.len { // 如果 x > 行长
		view.x = line.len // 设置为行长
	}
}

// shift_g moves the cursor to the last line of the file. (Vim: `G`)
// 将光标移动到文件的最后一行。（Vim: `G`）
fn (mut view View) shift_g() {
	view.set_y(view.lines.len - 1) // 设置 y 为最后一行
	view.from = view.y - view.page_height + 1 // 设置 from
	if view.from < 0 { // 如果 from < 0
		view.from = 0 // 设置为 0
	}
}

// shift_a appends a space at the end of the current line. (Similar to Vim: `A`)
// 在当前行末尾追加一个空格。（类似于 Vim: `A`）
fn (mut view View) shift_a() {
	line := view.line() // 获取行
	view.set_line('${line} ') // 设置行，追加空格
	view.x = view.line().len - 1 // 设置 x 为行长 - 1
}

// shift_i moves the cursor to the first non-whitespace character of the current line. (Vim: `^` or `I`)
// 将光标移动到当前行的第一个非空白字符。（Vim: `^` 或 `I`）
fn (mut view View) shift_i() {
	view.x = 0 // 设置 x 为 0
	for is_whitespace(u8(view.char())) { // 循环直到非空白字符
		view.x++ // 增加 x
	}
}

// gg moves the cursor to the first line of the file. (Vim: `gg`)
// 将光标移动到文件的第一行。（Vim: `gg`）
fn (mut view View) gg() {
	view.from = 0 // 设置 from 为 0
	view.set_y(0) // 设置 y 为 0
}

// zero moves the cursor to the beginning of the line. (Vim: `0`)
// 将光标移动到行的开头。（Vim: `0`）
fn (mut view View) zero() {
	view.x = 0 // 设置 x 为 0
}

// dollar moves the cursor to the end of the line. (Vim: `$`)
// 将光标移动到行的末尾。（Vim: `$`）
fn (mut view View) dollar() {
	line := view.line() // 获取行
	view.x = line.len // 设置 x 为行长
}

// shift_f scrolls the view down by one page. (Vim: `Ctrl+F`)
// 向下滚动视图一页。（Vim: `Ctrl+F`）
fn (mut view View) shift_f() {
	view.from += view.page_height // 增加 from
	if view.from >= view.lines.len { // 如果 from 超出
		view.from = view.lines.len - 1 // 设置为最后一行
	}
	view.set_y(view.from) // 设置 y 为 from
}

// shift_b scrolls the view up by one page. (Vim: `Ctrl+B`)
// 向上滚动视图一页。（Vim: `Ctrl+B`）
fn (mut view View) shift_b() {
	view.from -= view.page_height // 减少 from
	if view.from < 0 { // 如果 from < 0
		view.from = 0 // 设置为 0
	}
	view.set_y(view.from) // 设置 y 为 from
}

// dd deletes the current line and copies it to the yank buffer. (Vim: `dd`)
// 删除当前行并将其复制到 yank 缓冲区。（Vim: `dd`）
fn (mut view View) dd() {
	if view.lines.len == 0 { // 如果行数为 0
		return // 返回
	}
	mut ved := view.ved // 获取 ved
	ved.prev_key = gg.KeyCode.invalid // 设置 prev_key
	ved.prev_cmd = 'dd' // 设置 prev_cmd
	ved.ylines = [] // 初始化 ylines
	ved.ylines << view.line() // 添加行到 ylines
	view.lines.delete(view.y) // 删除行
	if view.y == view.lines.len { // 如果 y 等于行数
		view.k() // 向上移动
	}
	view.changed = true // 设置已更改
}

// shift_right indents the current line or the visually selected lines by one level. (Vim: `>`)
// 将当前行或视觉选择的行缩进一级。（Vim: `>`）
fn (mut view View) shift_right() {
	// No selection, shift current line
	// 无选择，缩进当前行
	if view.vstart == -1 { // 如果无选择
		view.set_line('\t${view.line()}') // 设置行，添加制表符
		return // 返回
	}
	for i := view.vstart; i <= view.vend; i++ {
		line := view.lines[i]
		view.lines[i] = '\t${line}'
	}
}

// shift_left un-indents the current line or the visually selected lines by one level. (Vim: `<`)
// 将当前行或视觉选择的行取消缩进一级。（Vim: `<`）
fn (mut view View) shift_left() {
	if view.vstart == -1 { // 如果无选择
		line := view.line() // 获取行
		if !line.starts_with('\t') { // 如果不以制表符开始
			return // 返回
		}
		view.set_line(line[1..]) // 设置行，去除第一个字符
		return // 返回
	}
	for i := view.vstart; i <= view.vend; i++ { // 遍历选择的行
		line := view.lines[i] // 获取行
		if !line.starts_with('\t') { // 如果不以制表符开始
			continue // 继续
		}
		view.lines[i] = line[1..] // 去除第一个字符
	}
}

// delete_char deletes the character currently under the cursor. (Vim: `x`)
// 删除光标下的当前字符。（Vim: `x`）
fn (mut v View) delete_char() {
	line := v.line() // 获取行
	if line.len < 1 || v.x >= line.len { // 如果行长 < 1 或 x >= 行长
		return // 返回
	}
	char_len := utf8_char_len(line[v.x]) // 获取字符长度
	mut new_line := line[..v.x] // 左侧部分
	if v.x + char_len < line.len { // 如果右侧有内容
		new_line += line[v.x + char_len..] // 添加右侧
	}
	v.set_line(new_line) // 设置新行
	if v.x >= new_line.len && new_line.len > 0 { // 如果 x 超出
		// Move cursor back to the last valid character boundary
		// 将光标移回最后一个有效字符边界
		mut i := new_line.len - 1 // 从末尾开始
		for i > 0 && (new_line[i] & 0xc0) == 0x80 { // 找到字符开始
			i-- // 减少 i
		}
		v.x = i // 设置 x
	}
}

// shift_c deletes from the cursor to the end of the line and returns the deleted text. (Similar to Vim: `C`)
// 从光标删除到行末，并返回删除的文本。（类似于 Vim: `C`）
fn (mut view View) shift_c() string {
	line := view.line() // 获取行
	s := line[..view.x] // 左侧部分
	deleted := line[view.x..] // 删除的部分
	view.set_line('${s} ') // 设置新行
	view.x = s.len // 设置 x
	return deleted // 返回删除的文本
}

// insert_text inserts the given string `s` at the current cursor position.
// 在当前光标位置插入给定的字符串 `s`。
fn (mut view View) insert_text(s string) {
	line := view.line() // 获取行
	if line.len == 0 { // 如果行长为 0
		view.set_line(s) // 设置行
		view.x = s.len // 设置 x
	} else { // 否则
		if view.x > line.len { // 如果 x > 行长
			view.x = line.len // 设置 x 为行长
		}
		left := line[..view.x] // 左侧
		right := line[view.x..] // 右侧
		// Insert char in the middle
		// 在中间插入字符
		res := '${left}${s}${right}' // 结果
		view.set_line(res) // 设置行
		view.x += s.len // 增加 x
	}
}

// backspace handles a backspace key press, deleting the character before the cursor or joining lines if at the beginning of a line.
// 处理退格键按下，删除光标前的字符，或如果在行首则合并行。
fn (mut view View) backspace() {
	if view.x == 0 { // 如果 x == 0
		if view.ved.cfg.backspace_go_up && view.y > 0 { // 如果配置允许向上退格且 y > 0
			view.x = 0 // 设置 x 为 0
			view.y-- // 减少 y
			view.x = view.lines[view.y].len // 设置 x 为上一行长度
			view.lines.delete(view.y + 1) // 删除下一行
			view.changed = true // 设置已更改
		}
		return // 返回
	}
	line := view.line() // 获取行
	// Find the previous UTF-8 character boundary
	// 找到上一个 UTF-8 字符边界
	mut i := view.x - 1 // 从 x-1 开始
	for i > 0 && (line[i] & 0xc0) == 0x80 { // 循环找到字符开始
		i-- // 减少 i
	}

	left := line[..i] // 左侧
	mut right := '' // 右侧
	if view.x < line.len { // 如果 x < 行长
		right = line[view.x..] // 设置右侧
	}
	view.set_line('${left}${right}') // 设置新行
	view.x = i // 设置 x
	if view.ved.prev_insert.len > 0 { // 如果 prev_insert 有内容
		// Just a simple backspace for prev_insert for now
		// 目前只是简单地为 prev_insert 退格
		view.ved.prev_insert = view.ved.prev_insert[..view.ved.prev_insert.len - 1] // TODO runes // 去除最后一个字符
	}
}

// yy yanks (copies) the current line into the yank buffer. (Vim: `yy`)
// 将当前行 yank（复制）到 yank 缓冲区。（Vim: `yy`）
fn (mut view View) yy() {
	view.ved.ylines = [view.line()] // 设置 ylines 为当前行
}

// p pastes the content of the yank buffer on new lines below the current cursor position. (Vim: `p`)
// 将 yank 缓冲区的内容粘贴到当前光标位置下方的行中。（Vim: `p`）
fn (mut view View) p() {
	for line in view.ved.ylines { // 遍历 ylines
		view.o() // 打开新行
		view.set_line(line) // 设置行
	}
}

// shift_o opens a new, indented line above the current line. (Vim: `O`)
// 在当前行上方打开一个新的缩进行。（Vim: `O`）
fn (mut view View) shift_o() {
	view.o_generic(0) // 调用 o_generic，delta=0
}

// o opens a new, indented line below the current line. (Vim: `o`)
// 在当前行下方打开一个新的缩进行。（Vim: `o`）
fn (mut view View) o() {
	view.o_generic(1) // 调用 o_generic，delta=1
}

fn (mut view View) o_generic(delta int) {
	view.y += delta // 增加 y
	// Insert the same amount of spaces/tabs as in prev line
	// 插入与上一行相同数量的空格/制表符
	prev_line := if view.lines.len == 0 || view.y == 0 { // 如果行数为 0 或 y == 0
		'' // 空
	} else { // 否则
		// Ensure index is valid before accessing
		// 确保索引有效
		prev_idx := view.y - 1 // 上一行索引
		if prev_idx >= 0 && prev_idx < view.lines.len { // 如果索引有效
			view.lines[prev_idx] // 获取上一行
		} else { // 否则
			// This case shouldn't happen based on the logic, but handle defensively
			// 这种情况不应该发生，但防御性处理
			'' // 默认无缩进
		}
	}
	nr_spaces, nr_tabs := nr_spaces_and_tabs_in_line(prev_line) // 获取空格和制表符数
	mut new_line := strings.repeat(`\t`, nr_tabs) + strings.repeat(` `, nr_spaces) // 创建新行
	if prev_line.ends_with('{') || prev_line.ends_with('{ ') { // 如果上一行以 { 或 { 结束
		new_line += '\t ' // 添加制表符和空格
	} else if !new_line.ends_with(' ') { // 如果不以空格结束
		new_line += ' ' // 添加空格
	}
	view.x = new_line.len - 1 // 设置 x
	if view.y >= view.lines.len { // 如果 y >= 行数
		view.lines << new_line // 添加新行
	} else { // 否则
		view.lines.insert(view.y, new_line) // 插入新行
	}
	view.changed = true // 设置已更改
}

// enter handles an enter key press in insert mode, splitting the current line at the cursor position.
// 处理插入模式下的回车键按下，在光标位置拆分当前行。
fn (mut view View) enter() {
	// Create new line
	// 创建新行
	// And move everything to the right of the cursor to it
	// 并将光标右侧的所有内容移动到新行
	pos := view.x // 位置
	line := view.line() // 获取行
	if pos >= line.len - 1 && line != '' && line != ' ' { // 如果位置 >= 行长 - 1 且行不为空且不为空格
		// {} insertion
		// {} 插入
		if line.ends_with('{ ') { // 如果以 { 结束
			view.o() // 打开新行
			view.x-- // 减少 x
			view.insert_text('}') // 插入 }
			view.y-- // 减少 y
			view.o() // 打开新行
			// view.insert_text('\t')
			// view.x = 0
		} else {
			view.o()
		}
		return
	}
	// if line == '' {
	// view.o()
	// return
	// }
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
}

// join joins the current line with the line below it. (Vim: `J`)
// 将当前行与下面的行合并。（Vim: `J`）
fn (mut view View) join() {
	if view.y == view.lines.len - 1 { // 如果是最后一行
		return // 返回
	}
	// Add next line to current line
	// 将下一行添加到当前行
	line := view.line() // 获取当前行
	second_line := view.lines[view.y + 1] // 获取下一行
	joined := line + second_line // 合并
	view.set_line(joined) // 设置合并行
	view.y++ // 增加 y
	view.dd() // 删除行
	view.y-- // 减少 y
	// view.prev_cmd = "J"
}

// y_visual yanks (copies) the visually selected lines into the yank buffer.
// 将视觉选择的行 yank（复制）到 yank 缓冲区。
fn (mut v View) y_visual() {
	mut ylines := []string{} // 初始化 ylines
	vtop, vbot := if v.vstart < v.vend { v.vstart, v.vend } else { v.vend, v.vstart } // 获取顶部和底部
	for i := vtop; i <= vbot; i++ { // 遍历选择的行
		ylines << v.lines[i] // 添加到 ylines
	}
	mut ved := v.ved // 获取 ved
	ved.ylines = ylines // 设置 ylines
	// Copy YY to clipboard if +(=) was pressed before
	// 如果之前按下了 +(=)，复制到剪贴板
	if ved.prev_key == .equal { // 如果 prev_key 是 equal
		ved.cb.copy(ylines.join('\n')) // 复制到剪贴板
	}
	v.vstart = -1 // 重置 vstart
	v.vend = -1 // 重置 vend
}

// d_visual deletes the visually selected lines and copies them to the yank buffer.
// 删除视觉选择的行并将它们复制到 yank 缓冲区。
fn (mut view View) d_visual() {
	vtop := if view.vstart < view.vend { view.vstart } else { view.vend } // 获取顶部
	view.y_visual() // 调用 y_visual
	for i := 0; i < view.ved.ylines.len; i++ { // 遍历 ylines
		view.lines.delete(vtop) // 删除行
	}
	// Move cursor to a valid position using k
	// 使用 k 将光标移动到有效位置
	if view.y >= view.lines.len { // 如果 y >= 行数
		view.y = view.lines.len // 设置 y
	} else { // 否则
		view.y += 1 // 增加 y
	}
	view.k() // 调用 k
}

// cw changes the word under the cursor: deletes it and enters insert mode. (Vim: `cw`)
// 更改光标下的单词：删除它并进入插入模式。（Vim: `cw`）
fn (mut view View) cw() {
	mut ved := view.ved // 获取 ved
	ved.prev_insert = '' // 重置 prev_insert
	view.dw(false) // 调用 dw
	ved.prev_cmd = 'cw' // 设置 prev_cmd
	// view.ved.set_insert() // don't call this since it resets prev_insert
	// view.ved.set_insert() // 不要调用，因为它重置 prev_insert
	ved.mode = .insert // 设置模式为插入
	ved.just_switched = true // 设置 just_switched
}

// returns the removed word
// 返回删除的单词
// dw deletes the word under the cursor. If `del_whitespace` is true, trailing whitespace is also deleted. (Vim: `dw`)
// dw 删除光标下的单词。如果 `del_whitespace` 为 true，也删除尾随空白。（Vim: `dw`）
fn (mut view View) dw(del_whitespace bool) { // string {
	mut ved := view.ved // 获取 ved
	typ := is_alpha(u8(view.char())) // 获取字符类型
	// While cur char has the same type - delete it
	// 当当前字符具有相同类型时 - 删除它
	for { // 循环
		line := view.line() // 获取行
		if view.x < 0 || view.x >= line.len - 1 { // 如果 x 超出范围
			break // 跳出
		}
		if typ == is_alpha(u8(view.char())) { // 如果类型相同
			// println('del x=$view.x len=$line.len')
			view.delete_char() // 删除字符
		} else { // 否则
			break // 跳出
		}
	}
	// Delete whitespace after the deleted word
	// 删除删除单词后的空白
	if del_whitespace { // 如果删除空白
		for is_whitespace(u8(view.char())) { // 循环空白
			line := view.line() // 获取行
			if view.x < 0 || view.x >= line.len { // 如果 x 超出范围
				break // 跳出
			}
			view.delete_char() // 删除字符
		}
	}
	ved.prev_cmd = 'dw' // 设置 prev_cmd
}

// returns the removed word
// 返回删除的单词
// db deletes the word backwards from the cursor position. (Vim: `db`)
// db 从光标位置向后删除单词。（Vim: `db`）
fn (mut view View) db(del_whitespace bool) { // string {
	mut ved := view.ved // 获取 ved
	typ := is_alpha(u8(view.char())) // 获取字符类型
	// While cur char has the same type - delete it
	// 当当前字符具有相同类型时 - 删除它
	for { // 循环
		line := view.line() // 获取行
		if view.x < 0 || view.x >= line.len - 1 { // 如果 x 超出范围
			break // 跳出
		}
		view.x-- // 减少 x
		if typ == is_alpha_underscore(u8(view.char())) { // 如果类型相同（包括下划线）
			// println('del x=$view.x len=$line.len')
			view.delete_char() // 删除字符
		} else { // 否则
			break // 跳出
		}
	}
	view.x++ // 增加 x
	// Delete whitespace after the deleted word
	// 删除删除单词后的空白
	/*
	if del_whitespace {
		for is_whitespace(u8(view.char())) {
			line := view.line()
			if view.x < 0 || view.x >= line.len {
				break
			}
			view.delete_char()
		}
	}
	*/
	ved.prev_cmd = 'db' // 设置 prev_cmd
}

// TODO COPY PASTA
// TODO 复制粘贴
// same as cw but deletes underscores
// 与 cw 相同但删除下划线
// ce changes the word/token under the cursor. Similar to `cw` but may use a different definition of a "word".
// ce 更改光标下的单词/标记。与 `cw` 类似，但可能使用不同的“单词”定义。
fn (mut view View) ce() {
	mut ved := view.ved // 获取 ved
	view.de() // 调用 de
	ved.prev_cmd = 'ce' // 设置 prev_cmd
	view.ved.set_insert() // 设置插入模式
}

// w moves the cursor forward to the beginning of the next word. (Vim: `w`)
// 将光标向前移动到下一个单词的开头。（Vim: `w`）
fn (mut view View) w() {
	line := view.line() // 获取行
	typ := is_alpha_underscore(view.char()) // 获取字符类型
	// Go to end of current word
	// 移动到当前单词的末尾
	for view.x < line.len - 1 && typ == is_alpha_underscore(view.char()) { // 循环
		view.x++ // 增加 x
	}
	// Go to start of next word
	// 移动到下一个单词的开头
	for view.x < line.len - 1 && view.char() == 32 { // 循环空格
		view.x++ // 增加 x
	}
}

// b moves the cursor backward to the beginning of the previous word. (Vim: `b`)
// 将光标向后移动到上一个单词的开头。（Vim: `b`）
fn (mut view View) b() {
	// line := view.line()
	// Go to start of prev word
	// 移动到上一个单词的开头
	for view.x > 0 && view.char() == 32 { // 循环空格
		view.x-- // 减少 x
	}
	typ := is_alpha_underscore(view.char()) // 获取字符类型
	// Go to start of current word
	// 移动到当前单词的开头
	for view.x > 0 && typ == is_alpha_underscore(view.char()) { // 循环
		view.x-- // 减少 x
	}
}

// de deletes from the cursor to the end of the current word/token. (Vim: `de`)
// 从光标删除到当前单词/标记的末尾。（Vim: `de`）
fn (mut view View) de() {
	mut ved := view.ved // 获取 ved
	typ := is_alpha_underscore(view.char()) // 获取字符类型
	// While cur char has the same type - delete it
	// 当当前字符具有相同类型时 - 删除它
	for { // 循环
		line := view.line() // 获取行
		if view.x >= 0 && view.x < line.len && typ == is_alpha_underscore(view.char()) { // 如果在范围内且类型相同
			view.delete_char() // 删除字符
		} else { // 否则
			break // 跳出
		}
	}
	ved.prev_cmd = 'de' // 设置 prev_cmd
}

// delete all characters before and after the cursor inside '', "", () etc
// 删除光标内 ''、""、() 等中的所有字符
// ci "Change inside". Deletes the text within a surrounding delimiter (like quotes or parentheses)
// based on the `key` pressed, and enters insert mode. (Vim: `ci'`)
// ci "Change inside"。根据按下的 `key`，删除包围分隔符内的文本（如引号或括号），并进入插入模式。（Vim: `ci'`）
fn (mut view View) ci(key gg.KeyCode) {
	mut ved := view.ved // 获取 ved
	line := view.line() // 获取行
	defer { // 延迟执行
		ved.prev_cmd = '' // 设置 prev_cmd
	}
	match key { // 匹配 key
		.apostrophe { // 单引号
			if !line.contains("'") { // 如果不包含 '
				return // 返回
			}
			mut start := view.x // 开始位置
			for line[start] != `'` { // 找到开始的 '
				start-- // 减少 start
			}
			mut end := view.x // 结束位置
			for line[end] != `'` { // 找到结束的 '
				end++ // 增加 end
			}
			view.set_line(line[..start + 1] + line[end..]) // 设置行
			view.x = start + 1 // 设置 x
			view.ved.set_insert() // 设置插入模式
		}
		._9 {} // 9
		else {} // 其他
	}
	// match
	// view.dw()
}

// zz centers the current line vertically on the screen. (Vim: `zz`)
// 将当前行在屏幕上垂直居中。（Vim: `zz`）
fn (mut view View) zz() {
	view.from = view.y - view.ved.page_height / 2 // 设置 from
	if view.from < 0 { // 如果 from < 0
		view.from = 0 // 设置为 0
	}
}

// r replaces the single character under the cursor with the character(s) in `s`. (Vim: `r`)
// 用 `s` 中的字符替换光标下的单个字符。（Vim: `r`）
fn (mut view View) r(s string) {
	view.delete_char() // 删除字符
	view.insert_text(s) // 插入文本
	view.x-- // 减少 x
}

// tt toggles to the previously active view/file.
// 切换到之前活动的视图/文件。
fn (mut view View) tt() {
	if view.prev_path == '' { // 如果 prev_path 为空
		return // 返回
	}
	mut ved := view.ved // 获取 ved
	ved.prev_key = .invalid // 设置 prev_key
	view.open_file(view.prev_path, 0) // 打开上一个文件
}

// move_to_line jumps the cursor and view to a specific `line` number.
// 将光标和视图跳转到特定的 `line` 行号。
fn (mut view View) move_to_line(line int) {
	view.prev_y = view.y // 保存 prev_y
	view.from = line // 设置 from
	view.set_y(line) // 设置 y
	view.zz() // 居中
}

// ctrl+a - increase number by one
// ctrl+a - 增加数字 1
// super_a finds the first number on the current line and increases it by `diff`. (Vim: `Ctrl+A` for +1)
// super_a 找到当前行上的第一个数字，并将其增加 `diff`。（Vim: `Ctrl+A` 为 +1）
fn (mut view View) super_a(diff int) {
	line := view.line() // 获取行
	mut num_start_pos := -1 // 数字开始位置
	for i, r in line { // 遍历行
		if r >= `0` && r <= `9` { // 如果是数字
			num_start_pos = i // 设置位置
			break // 跳出
		}
	}
	if num_start_pos == -1 { // 如果未找到
		return // 返回
	}
	s := line[num_start_pos..] // 从位置开始的字符串
	vals := s.fields() // 分割字段
	number := vals[0].int() // 转换为整数
	new_line := line.replace_once(number.str(), (number + diff).str()) // 替换
	view.set_line(new_line) // 设置新行
}

// is_alpha checks if a byte represents an alphanumeric character (`a-z`, `A-Z`, `0-9`).
// is_alpha 检查字节是否表示字母数字字符（`a-z`、`A-Z`、`0-9`）。
fn is_alpha(r u8) bool {
	return (r >= `a` && r <= `z`) || (r >= `A` && r <= `Z`) || (r >= `0` && r <= `9`) // 返回是否是字母或数字
}

// is_whitespace checks if a byte represents a whitespace character (space or tab).
// is_whitespace 检查字节是否表示空白字符（空格或制表符）。
fn is_whitespace(r u8) bool {
	return r == ` ` || r == `\t` // 返回是否是空格或制表符
}

// is_alpha_underscore checks if an integer (rune) represents an alphanumeric character, an underscore, a hash, or a dollar sign.
// is_alpha_underscore 检查整数（符文）是否表示字母数字字符、下划线、哈希或美元符号。
fn is_alpha_underscore(r int) bool {
	return is_alpha(u8(r)) || u8(r) == `_` || u8(r) == `#` || u8(r) == `$` // 返回是否是字母、数字、下划线、# 或 $
}

// break_text splits a single string `s` into an array of strings, ensuring no line exceeds `max` characters.
fn break_text(s string, max int) []string {
	mut lines := []string{}
	mut start := 0
	for i := 0; i < s.len; i++ {
		if i == s.len - 1 {
			// Include the very last char
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
