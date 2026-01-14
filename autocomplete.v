// Copyright (c) 2019 Alexander Medvednikov. All rights reserved. // 版权所有 (c) 2019 Alexander Medvednikov。保留所有权利
// Use of this source code is governed by a GPL license // 本源代码的使用受 GPL 许可证约束
// that can be found in the LICENSE file. // 可在 LICENSE 文件中找到
module main // 主模块

import gg // 导入 gg 图形库
import os // 导入 os 操作系统库
import time // 导入 time 时间库

const nr_elems_to_show_in_autocomplete = 12 // nr_elems_to_show_in_autocomplete 常量，自动完成中显示的元素数量

struct AutocompleteInfo { // AutocompleteInfo 结构体，自动完成信息
mut:
	vars []AutocompleteVar // 变量
}

struct AutocompleteVar { // AutocompleteVar 结构体，自动完成变量
	name string // 名称
	typ  string // 类型
mut:
	fields []AutocompleteField // 字段
}

struct AutocompleteField { // AutocompleteField 结构体，自动完成字段
	name string // 名称
	typ  string // 类型
}

fn (ved &Ved) draw_autocomplete_window() { // draw_autocomplete_window 函数，绘制自动完成窗口
	max_col_len := 45 // 最大列长度
	cur_word := ved.word_under_cursor_no_right() // 获取光标下单词（无右边）
	// println('1DRAW WINDOW cur word="${cur_word}"') // 打印（注释）
	mut width := int(f64(ved.cfg.char_width * max_col_len) * 1.5) // 宽度
	mut height := nr_elems_to_show_in_autocomplete * ved.cfg.line_height // 高度
	// Calculate position of the autocomplete box (next to the cursor) // 计算自动完成框的位置（光标旁边）
	x := ved.calc_cursor_x() // x
	y := ved.calc_cursor_y() + ved.cfg.line_height // y

	if cur_word != '' && ved.autocomplete_info.vars.len == 0 { // 如果当前单词不为空且变量长度为 0
		// Do not draw empty autocomplete window if there are no results and the user // 如果没有结果且用户在 `.` 后开始输入，不要绘制空的自动完成窗口
		// started typing after `.` // （注释）
		// println("NO RES, RET word='${cur_word}'") // 打印（注释）
		return // 返回
	}

	if ved.autocomplete_info.vars.len == 0 { // 如果变量长度为 0
		return // 返回
	}
	ved.gg.draw_rect_filled(x, y, width, height, gg.white) // 绘制填充矩形
	// ved.gg.draw_text(x + 10, y + 30, 'AUTOCOMPLETE', txt_cfg) // 绘制文本（注释）

	// for i, var in ved.autocomplete_info.vars {
	if ved.autocomplete_info.vars.len > 0 {
		var := ved.autocomplete_info.vars[0]
		// Calc max len of the first col to calculate first col width (to align second col)
		mut max_len := 0
		for field in var.fields {
			if field.name.len > max_len {
				max_len = field.name.len
			}
		}
		if max_len > max_col_len {
			max_len = max_col_len // + 4 // 4 - some spacing + space for ()
		}
		mut first_col_width := max_len * ved.cfg.char_width
		if first_col_width < 7 * ved.cfg.char_width {
			first_col_width = 7 * ved.cfg.char_width
		}

		// Draw var name + type
		nt := '${var.name}: ${var.typ}'
		ved.gg.draw_rect_filled(x + width, y, ved.cfg.char_width * nt.len, ved.cfg.line_height,
			gg.white)
		ved.gg.draw_text(x + width, y, nt, gg.TextCfg{
			...ved.cfg.txt_cfg
			bold: true
		})
		/*
		ved.gg.draw_rect(
			x: x + width
			y: y
			width: 100
			height: ved.cfg.line_height
			color: gg.white
		)
		*/
		mut i := 0 // number of filtered fields
		mut reached_bottom_edge := false
		for field in var.fields {
			if cur_word != '' && !field.name.to_lower().contains(cur_word.to_lower()) {
				continue
			}
			// Draw field name
			if !reached_bottom_edge {
				ved.gg.draw_text(x + 10, y + i * ved.cfg.line_height, field.name.limit(max_len),
					ved.cfg.txt_cfg)
				// Draw field type
				ved.gg.draw_text(x + 10 + first_col_width, y + i * ved.cfg.line_height,
					field.typ, gg.TextCfg{ ...ved.cfg.txt_cfg, color: gg.gray })
			}

			if i >= nr_elems_to_show_in_autocomplete - 1 {
				reached_bottom_edge = true
				// break
			}
			i++
		}

		// Draw number of fields and current number (e.g. "3/24")
		counter := '1/${i}'
		ved.gg.draw_text(x + width, y, counter, gg.TextCfg{
			...ved.cfg.txt_cfg
			align: .right
			color: gg.gray
		})
		// Draw time it took (debugging)
		ved.gg.draw_text(x + width, y + ved.cfg.line_height, ved.debug_info, gg.TextCfg{
			...ved.cfg.txt_cfg
			align: .right
			color: gg.green
		})
	}
}

fn (mut ved Ved) get_v_build_cmd() ?string {
	line_nr := ved.view.y + 1
	// file_name := os.base(ved.view.path)
	file_name := ved.view.path
	build_file := ved.get_build_file_location() or { return none }
	mut v_build_cmd := if build_file == '' { 'v .' } else { os.read_file(build_file) or {
			return none} }
	words := v_build_cmd.fields()
	mut dir_to_build := words[words.len - 1]
	module_name := get_module_name_from_file(ved.view.lines)
	if ved.view.path.contains('${module_name}/') {
		// dir_to_build = 'vlib/v/checker'
		dir_to_build = os.dir(ved.view.path)
	}
	// full_dir_to_build := os.join_path(ved.workspace, dir_to_build)
	full_dir_to_build := dir_to_build
	println('NNNdir_to_build="${full_dir_to_build}"')

	v_build_cmd = 'v -line-info "${file_name}:${line_nr}" ' + full_dir_to_build
	return v_build_cmd
}

// Calls `v -line-info "a.v:16" a.v`, parses output
fn (mut ved Ved) get_line_info() {
	ved.autocomplete_info.vars = []
	// cmd := 'v -line-info "${file_name}:${line_nr}" .' // ${ved.view.path}'
	v_build_cmd := ved.get_v_build_cmd() or { return }
	t := time.now()
	resp := os.execute(v_build_cmd) // or {
	time_diff := time.since(t)
	ved.debug_info = time_diff.str()
	// println('FAILED TO RUN V -line-info')
	// return
	//}
	println('v_build_cmd=')
	println(v_build_cmd)
	println('RESP=')
	println(resp.output)
	if resp.output.contains('not found among those parsed') {
	}
	// Parse the format
	/*
	===
	VAR cmd:string
	str:u8
	len:int
	is_lit:int
	===
	*/
	mut vars := resp.output.split('===')
	if vars.len == 0 {
		println('no vars text')
		return
	}
	println('VARS=')
	println(vars)

	for var_text in vars {
		if var_text == '' {
			continue
		}
		lines := var_text.trim_space().split('\n')
		if lines.len < 2 {
			continue
		}
		println('LINE 0')
		println(lines[0])
		mut var_line := lines[0]
		if !var_line.starts_with('VAR') {
			break
		}
		var_name_type_vals := var_line[3..].split(':')
		var_name, var_type := var_name_type_vals[0], var_name_type_vals[1]
		println('VARNAME=${var_name}')
		mut var := AutocompleteVar{
			name: var_name
			typ:  var_type
		}
		for i := 1; i < lines.len; i++ {
			vals := lines[i].split(':')
			if vals.len != 2 {
				continue
			}
			field_name := vals[0]
			field_type := vals[1]
			var.fields << AutocompleteField{field_name, field_type}
		}
		ved.autocomplete_info.vars << var
		// Now cache the type so that following lookups (pressing `.`) are instant
		ved.autocomplete_cache[var_type] = var.fields.clone()
	}
	// println(ved.autocomplete_info)
	ved.refresh = true
	ved.gg.refresh_ui()
	// exit(0)
}

// called when pressing Enter
fn (mut ved Ved) insert_suggested_field() {
	if unsafe { true } {
		return
	}
	if ved.autocomplete_info.vars.len == 0 {
		return
	}
	var := ved.autocomplete_info.vars[0]
	if var.fields.len == 0 {
		return
	}
	cur_word := ved.word_under_cursor_no_right()
	for field in var.fields {
		if !field.name.to_lower().contains(cur_word.to_lower()) {
			continue
		}
		ved.view.x--
		ved.view.db(false)
		ved.view.insert_text(field.name)
		ved.view.delete_char() // TODO extra unneeded char for some reason, improve db() algo instead
		break
		// if i >= nr_elems_to_show_in_autocomplete - 1 {
		// break
		//}
	}
	ved.mode = .insert
}

/*
fn (mut ved Ved) save_autocomplete_cache() {
}

fn (mut ved Ved) load_autocomplete_cache() {
}
*/

fn get_module_name_from_file(lines []string) string {
	for line in lines {
		if line.contains('module ') {
			return line.replace('module ', '').trim_space()
		}
	}
	return ''
}
