module main // 主模块

import gg // 导入 gg 图形库
import os // 导入 os 操作系统库
import uiold // 导入 uiold UI 库

fn (mut ved Ved) draw() { // draw 函数，绘制整个界面
	mut view := ved.view // 获取当前视图
	split_width := ved.split_width() // 获取分割宽度
	ved.page_height = ved.win_height / ved.cfg.line_height - 1 // 计算页面高度
	view.page_height = ved.page_height // 设置视图页面高度
	// Splits from and to // 分割的起始和结束
	from, to := ved.get_splits_from_to() // 获取分割的起始和结束索引
	// Not a full refresh? Means we need to refresh only current split. // 非完整刷新？意味着只需要刷新当前分割
	if !ved.refresh { // 如果不是刷新
		// split_x := split_width * (ved.cur_split - from) // 计算分割 x 坐标
		// ved.gg.draw_rect_filled(split_x, 0, split_width - 1, ved.win_height, ved.cfg.bgcolor) // 绘制填充矩形
	}
	// Coords // 坐标
	y := ved.calc_cursor_y() // 计算光标 y 坐标
	// Cur line // 当前行
	line_x := split_width * (ved.cur_split - from) + ved.view.padding_left + 10 // 计算行 x 坐标
	line_width := split_width - ved.view.padding_left - 10 // 计算行宽度
	ved.gg.draw_rect_filled(line_x, y, line_width, ved.cfg.line_height, ved.cfg.vcolor) // 绘制当前行背景
	// V selection // V 选择
	mut v_from := ved.view.vstart + 1 // 选择起始行
	mut v_to := ved.view.vend + 1 // 选择结束行
	if view.vend < view.vstart { // 如果结束行小于起始行
		// Swap start and end if we go beyond the start // 如果超出起始位置，交换起始和结束
		v_from = ved.view.vend + 1 // 交换 v_from
		v_to = ved.view.vstart + 1 // 交换 v_to
	}
	for yy := v_from; yy <= v_to; yy++ { // 循环绘制选择区域
		ved.gg.draw_rect_filled(line_x, (yy - ved.view.from) * ved.cfg.line_height, line_width,
			ved.cfg.line_height, ved.cfg.vcolor) // 绘制选择行背景
	}
	// Black title background // 黑色标题背景
	ved.gg.draw_rect_filled(0, 0, ved.win_width, ved.cfg.line_height, ved.cfg.title_color) // 绘制标题背景
	// Current split has dark blue title // 当前分割有深蓝色标题
	// ved.gg.draw_rect_filled(split_x, 0, split_width, ved.cfg.line_height, gx.rgb(47, 11, 105)) // 绘制分割标题
	// Title (file paths) // 标题（文件路径）
	for i := to - 1; i >= from; i-- { // 循环绘制标题
		v := ved.views[i] // 获取视图
		mut name := v.short_path // 获取短路径
		if v.changed && !v.path.ends_with('/out') { // 如果已更改且不以 /out 结尾
			name = '${name} [+]' // 添加 [+] 标记
		}
		ved.gg.draw_text(ved.split_x(i - from) + v.padding_left + 10, 1, name, ved.cfg.file_name_cfg) // 绘制文件名
	}
	// Git diff stats // Git 差异统计
	if ved.git_diff_plus != '+' { // 如果 git_diff_plus 不为 '+'
		ved.gg.draw_text(ved.win_width - 400, 1, ved.git_diff_plus, ved.cfg.plus_cfg) // 绘制加号统计
	}
	if ved.git_diff_minus != '-' { // 如果 git_diff_minus 不为 '-'
		ved.gg.draw_text(ved.win_width - 350, 1, ved.git_diff_minus, ved.cfg.minus_cfg) // 绘制减号统计
	}
	// Workspaces // 工作区
	nr_spaces := ved.workspaces.len // 工作区数量
	cur_space := ved.workspace_idx + 1 // 当前工作区索引
	space_name := short_space(ved.workspace) // 工作区名称
	ved.gg.draw_text(ved.win_width - 220, 1, '[${space_name}]', ved.cfg.file_name_cfg) // 绘制工作区名称
	ved.gg.draw_text(ved.win_width - 100, 1, '${cur_space}/${nr_spaces}', ved.cfg.file_name_cfg) // 绘制工作区索引
	// Time // 时间
	ved.gg.draw_text(ved.win_width - 50, 1, ved.now.hhmm(), ved.cfg.file_name_cfg) // 绘制时间
	// ved.gg.draw_text(ved.win_width - 550, 1, now.hhmmss(), file_name_cfg) // 绘制完整时间（注释）
	// vim top right next to current time // vim 顶部右侧靠近当前时间
	/*
	if ved.start_unix > 0 { // 如果 start_unix > 0
		minutes := '1m' //ved.timer.minutes() // 分钟
		ved.gg.draw_text(ved.win_width - 300, 1, '${minutes}m' !, // 绘制分钟
			ved.cfg.file_name_cfg)
	}
	*/
	if ved.cur_task != '' { // 如果当前任务不为空
		// Draw current task // 绘制当前任务
		task_text_width := ved.cur_task.len * ved.cfg.char_width // 任务文本宽度
		task_x := ved.win_width - split_width - task_text_width - 70 // 任务 x 坐标
		// ved.timer.gg.draw_text(task_x, 1, ved.timer.cur_task.to_upper(), file_name_cfg) // 绘制任务（注释）
		ved.gg.draw_text(task_x, 1, ved.cur_task, ved.cfg.file_name_cfg) // 绘制当前任务
		// Draw current task time // 绘制当前任务时间
		task_time_x := (ved.nr_splits - 1) * split_width - 50 // 任务时间 x 坐标
		ved.gg.draw_text(task_time_x, 1, '${ved.task_minutes()}m', ved.cfg.file_name_cfg) // 绘制任务分钟
	}
	// Draw pomodoro timer // 绘制番茄钟计时器
	if ved.timer.pom_is_started { // 如果番茄钟已开始
		ved.gg.draw_text(split_width - 50, 1, '${ved.pomodoro_minutes()}m', ved.cfg.file_name_cfg) // 绘制番茄钟分钟
	}
	// Draw "i" in insert mode // 在插入模式下绘制 "i"
	if ved.mode == .insert { // 如果模式为插入
		ved.gg.draw_text(5, 1, '-i-', ved.cfg.file_name_cfg) // 绘制插入模式指示器
	}
	// Draw "v" in visual mode // 在视觉模式下绘制 "v"
	if ved.mode == .visual { // 如果模式为视觉
		ved.gg.draw_text(5, 1, '-v-', ved.cfg.file_name_cfg) // 绘制视觉模式指示器
	}
	// Splits // 分割
	// println('\nsplit from=$from to=$to nrviews=$ved.views.len refresh=$ved.refresh') // 打印分割信息（注释）
	for i := to - 1; i >= from; i-- { // 循环绘制分割
		// J or K is pressed (full refresh disabled for performance), only redraw current split // 按下 J 或 K（为性能禁用完整刷新），仅重绘当前分割
		if !ved.refresh && i != ved.cur_split { // 如果不是刷新且不是当前分割
			// continue // 继续（注释）
		}
		// t := glfw.get_time() // 时间（注释）
		ved.draw_split(i, from) // 绘制分割
		// println('draw split $i: ${ glfw.get_time() - t }') // 打印绘制时间（注释）
	}
	// Cur fn name (top right of current split) // 当前函数名（当前分割的右上角）
	if view.y != view.from { // Don't draw current fn name if the first visible line is selected // 如果选择的第一可见行，则不绘制当前函数名
		cur_fn_width := ved.cfg.char_width * ved.cur_fn_name.len // 当前函数名宽度
		cur_fn_x := (ved.cur_split % ved.nr_splits + 1) * split_width - cur_fn_width - 3 // 当前函数名 x 坐标
		cur_fn_y := ved.cfg.line_height // 当前函数名 y 坐标
		ved.gg.draw_rect( // 绘制矩形
			x:     cur_fn_x // x 坐标
			y:     cur_fn_y // y 坐标
			w:     cur_fn_width // 宽度
			h:     ved.cfg.line_height // 高度
			color: ved.cfg.bgcolor // gx.rgb(40, 40, 40) // 颜色
		)
		ved.gg.draw_text(cur_fn_x, cur_fn_y, ved.cur_fn_name, ved.cfg.comment_cfg) // 绘制当前函数名
	}
	// Debugger variables // 调试器变量
	if ved.mode == .debugger && ved.debugger.output.vars.len > 0 { // 如果模式为调试器且变量长度 > 0
		ved.draw_debugger_variables() // 绘制调试器变量
	}
	// Cursor // 光标
	mut cursor_x := ved.calc_cursor_x() // 计算光标 x 坐标
	ved.draw_cursor(cursor_x, y) // 绘制光标

	// ved.gg.draw_text_def(cursor_x + 500, y - 1, 'tab=$cursor_tab_off x=$cursor_x view_x=$ved.view.x') // 调试文本（注释）
	// query window // 查询窗口
	if ved.mode == .query { // 如果模式为查询
		ved.draw_query() // 绘制查询
	} else if ved.mode == .autocomplete { // 否则如果模式为自动完成
		ved.draw_autocomplete_window() // 绘制自动完成窗口
	}
	// Big red error line at the bottom // 底部的大红色错误行
	if ved.error_line != '' { // 如果错误行不为空
		ved.gg.draw_rect_filled(0, ved.win_height - ved.cfg.line_height, ved.win_width,
			ved.cfg.line_height, ved.cfg.errorbgcolor) // 绘制错误背景
		ved.gg.draw_text(3, ved.win_height - ved.cfg.line_height, ved.error_line, gg.TextCfg{ // 绘制错误文本
			size:  ved.cfg.text_size // 字体大小
			color: gg.white // 颜色
			align: gg.align_left // 对齐
		})
	}
	if ved.cfg.show_file_tree { // 如果显示文件树
		// Draw file tree // 绘制文件树
		ved.tree.draw(mut ved) // 绘制文件树
	}
}

fn (ved &Ved) split_x(i int) int { // split_x 函数，计算分割的 x 坐标
	return ved.split_width() * i // 返回分割宽度乘以索引
}

fn (mut ved Ved) draw_split(i int, split_from int) { // draw_split 函数，绘制单个分割
	view := ved.views[i] // 获取视图
	// Determine initial comment state for the first visible line // 确定第一可见行的初始注释状态
	// (handle /**/ comments blocks that start before current page) // （处理在当前页面之前开始的 /**/ 注释块）
	mut current_is_ml_comment := false // 当前是否为多行注释
	if view.hl_on { // 如果高亮开启
		current_is_ml_comment = ved.determine_ml_comment_state(view, view.from) // 确定多行注释状态
	}
	ext := os.file_ext(view.path) // Cache extension // 缓存扩展名
	mcomment := get_mcomment_by_ext(ext) // Cache delimiters // 缓存分隔符

	split_width := ved.split_width() // 分割宽度
	split_x := split_width * (i - split_from) // 分割 x 坐标
	// Vertical split line // 垂直分割线
	ved.gg.draw_line(split_x, ved.cfg.line_height + 1, split_x, ved.win_height, ved.cfg.split_color) // 绘制分割线
	// Lines // 行
	mut line_nr_rel := 1 // relative y on screen // 屏幕上的相对 y
	for j := view.from; j < view.from + ved.page_height && j < view.lines.len; j++ { // 循环绘制行
		line := view.lines[j] // 获取行
		if line.len > 5000 { // 如果行长度 > 5000
			println('line len too big! views[${i}].lines[${j}] (${line.len}) path=${ved.view.path}') // 打印警告
			continue // 继续
		}
		x := split_x + view.padding_left // x 坐标
		y := line_nr_rel * ved.cfg.line_height // y 坐标
		// Error bg // 错误背景
		if view.error_y == j { // 如果错误行等于 j
			ved.gg.draw_rect_filled(x + 10, y - 1, split_width - view.padding_left - 10,
				ved.cfg.line_height, ved.cfg.errorbgcolor) // 绘制错误背景
		}
		// Breakpoint red circle // 断点红色圆圈
		if view.breakpoints.contains(j) { // 如果断点包含 j
			ved.gg.draw_circle_filled(split_x + 3, y + ved.cfg.line_height / 2 - 1, 5,
				gg.red) // 绘制断点圆圈
		}
		// Breakpoint yellow line // 断点黄色线
		if ved.mode == .debugger && ved.cur_split == i && ved.debugger.output.line_nr != 0
			&& ved.debugger.output.line_nr == j + 1 { // 如果调试模式且当前分割且行号匹配
			line_width := split_width - view.padding_left - 10 // 行宽度
			ved.gg.draw_rect_filled(x + 10, y, line_width, ved.cfg.line_height, breakpoint_color) // 绘制断点线
		}
		// Line number // 行号
		line_number := j + 1 // 行号
		ved.gg.draw_text(x + 3, y, '${line_number}', ved.cfg.line_nr_cfg) // 绘制行号
		// Tab offset // Tab 偏移
		mut line_x := x + 10 // 行 x 坐标
		mut nr_tabs := 0 // Tab 数量
		// for k := 0; k < line.len; k++ { // 循环（注释）
		for c in line { // 循环行中的字符
			if c != `\t` { // 如果不是 Tab
				break // 跳出
			}
			nr_tabs++ // Tab 数量加一
			line_x += ved.cfg.char_width * ved.cfg.tab_size // 增加 x 坐标
		}
		mut s := line[nr_tabs..] // tabs have been skipped, remove them from the string // Tab 已跳过，从字符串中移除
		if s == '' { // 如果字符串为空
			line_nr_rel++ // 相对行号加一
			continue // 继续
		}
		// Number of chars to display in this view // 此视图中显示的字符数
		// mut max := (split_width - view.padding_left - ved.cfg.char_width * TAB_SIZE * // 最大值（注释）
		// nr_tabs) / ved.cfg.char_width - 1 // （注释）
		max := ved.max_chars(i, nr_tabs) // 最大字符数
		if view.y == j { // 如果视图 y 等于 j
			// Display entire line if its current // 如果是当前行，显示整行
			// if line.len > max { // 如果行长度 > 最大值（注释）
			// ved.gg.draw_rect_filled(line_x, y - 1, ved.win_width, line_height, vcolor) // 绘制背景（注释）
			// } // （注释）
			// max = line.len // 最大值 = 行长度（注释）
		}
		// if s.contains('width :=') { // 如果包含 'width :='（注释）
		// println('"$s" max=$max') // 打印（注释）
		//} // （注释）
		// Handle utf8 codepoints // 处理 UTF8 码点
		// old_len := s.len // 旧长度（注释）
		if s.len != s.len_utf8() { // 如果长度不等于 UTF8 长度
			u := s.runes() // 获取符文
			if max > 0 && max < u.len { // 如果最大值 > 0 且 < 符文长度
				s = u[..max].string() // 截取字符串
			}
		} else { // 否则
			if max > 0 && max < s.len { // 如果最大值 > 0 且 < 字符串长度
				s = s[..max] // 截取字符串
			}
		}

		if view.hl_on { // 如果高亮开启
			// Handle multi page /**/ // 处理多页 /**/
			// Find the position of start and end comment delimiters on the current line. // 在当前行上查找开始和结束注释分隔符的位置
			// This now uses the string-based delimiters from the Mcomment struct. // 这现在使用 Mcomment 结构体中的基于字符串的分隔符
			start_comment_pos := s.index(mcomment.start) or { -1 } // 开始注释位置
			end_comment_pos := s.index(mcomment.end) or { -1 } // 结束注释位置

			// This logic handles rendering for a line that starts inside a multi-line comment. // 此逻辑处理从多行注释内部开始的行的渲染
			if current_is_ml_comment { // 如果当前是多行注释
				if end_comment_pos != -1 { // The multi-line comment ends on this line. // 多行注释在此行结束
					// Draw the part of the line that is inside the comment. // 绘制行中注释内部的部分
					// The slice now uses `mcomment.end.len` for an accurate length. // 切片现在使用 `mcomment.end.len` 以获得准确长度
					comment_part := s[..end_comment_pos + mcomment.end.len] // 注释部分
					ved.gg.draw_text(line_x, y, comment_part, ved.cfg.comment_cfg) // 绘制注释部分

					// Draw the rest of the line (after the comment) using standard syntax highlighting. // 使用标准语法高亮绘制行的其余部分（注释后）
					normal_part := s[end_comment_pos + mcomment.end.len..] // 正常部分
					if normal_part.len > 0 { // 如果正常部分长度 > 0
						// Calculate the starting x-position for the text after the comment. // 计算注释后文本的起始 x 位置
						normal_part_x := line_x + ved.text_width_tabs(comment_part) // 正常部分 x 坐标
						ved.draw_text_line_standard_syntax(normal_part_x, y, normal_part,
							ext) // 绘制正常部分
					}

					// Update the state since the comment block is now closed. // 更新状态，因为注释块现在已关闭
					current_is_ml_comment = false // 当前不是多行注释
				} else { // The entire line is still inside the comment. // 整行仍在注释内
					// Draw the whole line with the comment color. // 用注释颜色绘制整行
					ved.gg.draw_text(line_x, y, s, ved.cfg.comment_cfg) // 绘制整行
					// The state `current_is_ml_comment` remains true for the next line. // 状态 `current_is_ml_comment` 对下一行保持为 true
				}
			} else { // current_is_ml_comment is false // 当前不是多行注释
				if start_comment_pos != -1
					&& (end_comment_pos == -1 || end_comment_pos < start_comment_pos) { // Comment starts here and continues // 注释从这里开始并继续
					// Draw normal part before / * // 在 / * 之前绘制正常部分
					normal_part := s[..start_comment_pos] // 正常部分
					if normal_part.len > 0 { // 如果正常部分长度 > 0
						ved.draw_text_line_standard_syntax(line_x, y, normal_part, ext) // 绘制正常部分
					}
					// Draw comment part from / * onwards // 从 / * 开始绘制注释部分
					comment_part := s[start_comment_pos..] // 注释部分
					comment_part_x := line_x + ved.text_width_tabs(normal_part) // 注释部分 x 坐标
					ved.gg.draw_text(comment_part_x, y, comment_part, ved.cfg.comment_cfg) // 绘制注释部分
					current_is_ml_comment = true // Update state for next line // 更新下一行状态
				} else { // No multiline comment start OR it's a single-line /* ... */ // 没有多行注释开始或它是单行 /* ... */
					// Use the standard highlighter for the whole line // 为整行使用标准高亮器
					ved.draw_text_line_standard_syntax(line_x, y, s, ext) // 绘制整行
					// current_is_ml_comment remains false // current_is_ml_comment 保持为 false
				}
			}
		} else { // 否则
			ved.gg.draw_text(line_x, y, s, ved.cfg.txt_cfg) // 绘制文本
		}
		line_nr_rel++ // 相对行号加一
	}
}

fn (ved &Ved) max_chars(view_idx int, nr_tabs int) int { // max_chars 函数，计算最大字符数
	width := ved.split_width() - ved.views[view_idx].padding_left - ved.cfg.char_width * ved.cfg.tab_size * nr_tabs // 宽度计算
	return width / ved.cfg.char_width - 1 // 返回最大字符数
}

fn (ved &Ved) draw_cursor(cursor_x int, y int) { // draw_cursor 函数，绘制光标
	// Draw marked text (IME pre-edit) // 绘制标记文本（IME 预编辑）
	mut cur_x := cursor_x // 当前 x 坐标
	if ved.marked_text != '' { // 如果标记文本不为空
		// Draw a light background for marked text // 为标记文本绘制浅色背景
		text_w := ved.gg.text_width(ved.marked_text) // 文本宽度
		ved.gg.draw_rect_filled(cursor_x, y, text_w, ved.cfg.line_height, gg.rgb(60, 60, 60)) // 绘制背景
		ved.gg.draw_text(cursor_x, y, ved.marked_text, ved.cfg.txt_cfg) // 绘制标记文本
		// Draw an underline // 绘制下划线
		ved.gg.draw_rect_filled(cursor_x, y + ved.cfg.line_height - 2, text_w, 2, gg.white) // 绘制下划线
		cur_x += text_w // 更新当前 x 坐标
	}

	// println('CURSOR WIDTH=${ved.cfg.char_width}') // 打印光标宽度（注释）
	match ved.cfg.cursor_style { // 匹配光标样式
		.block { // 块状
			ved.gg.draw_rect_empty(cur_x, y, ved.cfg.char_width, ved.cfg.line_height,
				ved.cfg.cursor_color) // 绘制空矩形
		}
		.beam { // 光束
			ved.gg.draw_rect_filled(cur_x, y, 2, ved.cfg.line_height, ved.cfg.cursor_color) // 绘制填充矩形
		}
		.variable { // 可变
			if ved.mode == .insert { // 如果模式为插入
				ved.gg.draw_rect_filled(cur_x, y, 2, ved.cfg.line_height, ved.cfg.cursor_color) // 绘制填充矩形
			} else { // 否则
				ved.gg.draw_rect_empty(cur_x, y, ved.cfg.char_width, ved.cfg.line_height,
					ved.cfg.cursor_color) // 绘制空矩形
			}
		}
	}
	// Sync IME position for macOS/Linux // 为 macOS/Linux 同步 IME 位置
	$if macos { // 如果是 macOS
		uiold.set_ime_position(cur_x, y, ved.cfg.line_height) // 设置 IME 位置
	}
}

fn prev_utf8_boundary(s string, idx int) int { // prev_utf8_boundary 函数，获取前一个 UTF8 边界
	mut i := idx // 索引
	if i <= 0 { // 如果索引 <= 0
		return 0 // 返回 0
	}
	if i > s.len { // 如果索引 > 字符串长度
		i = s.len // 设置为字符串长度
	}
	for i > 0 && i < s.len && (s[i] & 0xc0) == 0x80 { // 循环查找 UTF8 边界
		i-- // 索引减一
	}
	return i // 返回索引
}

fn (ved &Ved) x_of_byte_idx(line string, byte_idx int) int { // x_of_byte_idx 函数，根据字节索引计算 x 坐标
	mut idx := byte_idx // 索引
	if idx <= 0 { // 如果索引 <= 0
		return 0 // 返回 0
	}
	if idx > line.len { // 如果索引 > 行长度
		idx = line.len // 设置为行长度
	}
	idx = prev_utf8_boundary(line, idx) // 获取前一个 UTF8 边界
	mut w := 0 // 宽度
	mut last := 0 // 最后位置
	mut i := 0 // 索引
	for i < idx { // 循环
		if line[i] == `\t` { // 如果是 Tab
			if i > last { // 如果 i > last
				w += ved.gg.text_width(line[last..i]) // 增加宽度
			}
			w += ved.cfg.tab_size * ved.cfg.char_width // 增加 Tab 宽度
			i++ // 索引加一
			last = i // 更新 last
			continue // 继续
		}
		if (line[i] & 0x80) == 0 { // 如果是 ASCII
			i++ // 索引加一
		} else { // 否则
			i += utf8_char_len(line[i]) // 增加 UTF8 字符长度
		}
	}
	if idx > last { // 如果 idx > last
		w += ved.gg.text_width(line[last..idx]) // 增加宽度
	}
	return w // 返回宽度
}

fn (ved &Ved) text_width_tabs(s string) int { // text_width_tabs 函数，计算包含 Tab 的文本宽度
	return ved.x_of_byte_idx(s, s.len) // 返回字节索引的 x 坐标
}

fn (ved &Ved) calc_cursor_x() int { // calc_cursor_x 函数，计算光标 x 坐标
	line := ved.view.line() // 获取行
	from := ved.workspace_idx * ved.nr_splits // 从
	split_width := ved.split_width() // 分割宽度
	line_x := split_width * (ved.cur_split - from) + ved.view.padding_left + 10 // 行 x 坐标
	return line_x + ved.x_of_byte_idx(line, ved.view.x) // 返回光标 x 坐标
}

fn (ved &Ved) calc_cursor_y() int { // calc_cursor_y 函数，计算光标 y 坐标
	y := (ved.view.y - ved.view.from) * ved.cfg.line_height + ved.cfg.line_height // y 坐标
	return y // 返回 y 坐标
}
