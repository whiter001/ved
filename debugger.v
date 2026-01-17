// Copyright (c) 2019-2023 Alexander Medvednikov. All rights reserved. // 版权所有 (c) 2019-2023 Alexander Medvednikov。保留所有权利
// Use of this source code is governed by a GPL license // 本源代码的使用受 GPL 许可证约束
// that can be found in the LICENSE file. // 可在 LICENSE 文件中找到
module main

// 主模块
import os // 导入 os 操作系统库
import term // 导入 term 终端库
import time // 导入 time 时间库
import gg // 导入 gg 图形库
import strings // 导入 strings 字符串库

const breakpoint_color = gg.rgb(136, 136, 97) // yellow // 断点颜色 = 黄色

const debugger_name_color = gg.rgb(197, 134, 192) // pink // 调试器名称颜色 = 粉色

struct Debugger { // Debugger 结构体
mut:
	// 可变
	p      os.Process     // p 进程
	output DebuggerOutput // output 调试器输出
}

struct DebuggerOutput { // DebuggerOutput 结构体
mut:
	// 可变
	vars []DebuggerVariable // vars 变量数组

	line_nr int // line at which "->" points // "->" 指向的行号
}

struct DebuggerVariable { // DebuggerVariable 结构体
	name string // name 名称
	typ  string // typ 类型
mut:
	// 可变
	value string // value 值
}

fn (mut ved Ved) run_debugger(breakpoints []int) { // run_debugger 函数，运行调试器
	if !ved.view.path.ends_with('.v') { // 如果路径不以 '.v' 结尾
		println('Debugger only works with V files for now') // 打印调试器仅适用于 V 文件
		return
	}
	os.system('v -w -g -o /tmp/a ${ved.view.path}') // 系统命令编译 V 文件
	ved.debugger = new_debugger('/tmp/a') // 新调试器
	ved.debugger.run() // 运行

	for breakpoint in breakpoints { // 遍历断点
		_ = breakpoint // 忽略断点
		// view.debugger.send_cmd('b main__foo') // （注释）
	}
	ved.debugger.send_cmd('b main__foo') // 发送命令设置断点
	ved.debugger.send_cmd('target stop-hook add --one-liner "frame variable"') // 发送命令添加停止钩子
	ved.debugger.wait_for('Breakpoint ') or { panic(err) } // 等待断点

	ved.debugger.send_cmd('run') // 发送运行命令

	for { // 无限循环
		resp := ved.debugger.wait_for(' stop reason') or { break } // 等待停止原因
		time.sleep(100 * time.millisecond) // 睡眠100毫秒
		// println('<<<<<<<<<<<<<<<<') // （注释）
		// println(resp) // （注释）
		// println('>>>>>>>>>>>>>>>>') // （注释）
		ved.debugger.parse_output(resp) // 解析输出
		return
	}

	ved.debugger.p.close() // 关闭进程
	ved.debugger.p.wait() // 等待进程
	dump(ved.debugger.p.code) // 转储进程码
}

fn (mut d Debugger) send_cmd(cmd string) { // send_cmd 函数，发送命令
	eprintln(term.bright_yellow('\n\n> sending command: ${cmd}')) // 错误打印发送命令
	d.p.stdin_write('${cmd}\n') // 写入标准输入
}

fn (mut d Debugger) wait_for(what string) !string { // wait_for 函数，等待
	mut sb := strings.new_builder(100) // 字符串构建器
	eprintln(term.bright_blue('> waiting for: ${what}')) // 错误打印等待
	// now := time.now() // （注释）
	for d.p.is_alive() { // 当进程存活
		line := d.p.stdout_read() // 读取标准输出
		// d.p.stderr_read() // （注释）
		sb.write_string(line) // 写入字符串
		eprint('line len: ${line.len:5} | ${line}') // 打印行长度
		if line.contains(what) { // 如果包含
			return sb.str() // 返回字符串
			// break // （注释）
		}
		if line.contains('exited with status') { // 如果包含退出状态
			return error('process exited') // 返回错误
		}
	}
	return '' // 返回空
}

fn new_debugger(arg string) Debugger { // new_debugger 函数，新调试器
	mut d := Debugger{ // 可变调试器
		p: os.new_process(os.find_abs_path_of_executable('lldb') or { panic(err) }) // 新进程 lldb
	}
	d.p.set_args([arg]) // 设置参数
	d.p.set_work_folder(os.getwd()) // 设置工作文件夹
	d.p.set_redirect_stdio() // 设置重定向标准输入输出
	return d // 返回调试器
}

fn (mut d Debugger) run() { // run 函数
	d.p.run() // 运行进程
}

fn (mut view View) add_breakpoint(line_nr int) { // add_breakpoint 函数，添加断点
	view.breakpoints << line_nr // 添加行号到断点
}

fn (mut d Debugger) parse_output(s string) { // parse_output 函数，解析输出
	// d.output = d.parse_vars(s, false) // （注释）
	d.add_output(d.parse_vars(s, false)) // 添加输出
}

// merges old and new output, so that old vars are not lost and var positions are not changed (otherwise // 合并旧输出和新输出，以便旧变量不会丢失，变量位置不会改变（否则UI会跳动）
// UI becomes jumpy) // UI 会跳动
fn (mut d Debugger) add_output(new_output DebuggerOutput) { // add_output 函数，添加输出
	loop1: for new_var in new_output.vars { // 循环新变量
		for i, var in d.output.vars { // 遍历旧变量
			// Update value // 更新值
			if var.name == new_var.name { // 如果名称匹配
				d.output.vars[i].value = new_var.value // 更新值
				continue loop1 // 继续循环1
			}
		}
		// Add a new var to the end // 添加新变量到末尾
		d.output.vars << new_var // 添加新变量
	}
	d.output.line_nr = new_output.line_nr // 设置行号
}

fn (mut d Debugger) parse_vars(s string, is_struct bool) DebuggerOutput { // parse_vars 函数，解析变量
	mut res := DebuggerOutput{} // 可变结果
	lines := s.split('\n') // 分割行
	for line in lines { // 遍历行
		// Get variables: "(int) a = 3" // 获取变量："(int) a = 3"
		if line.contains(' = ') && (is_struct || line.contains(') ')) { // structs don't contain (string) // 结构体不包含 (string)
			var := d.parse_var(line, s, is_struct) // 解析变量
			if var.name != '' { // 如果名称不为空
				res.vars << var // 添加变量
			}
		}
		// Get yellow line number // 获取黄色行号
		else if line.starts_with('-> ') { // 如果以 '-> ' 开始
			// "-> 2   		str := 'hello'" // "-> 2   		str := 'hello'"
			vals := line.fields() // 字段
			res.line_nr = vals[1].int() // 设置行号
		}
	}
	// println('parse_vars res=') // （注释）
	// println(res) // （注释）
	return res // 返回结果
}

fn (mut d Debugger) parse_var(line string, s string, is_struct bool) DebuggerVariable { // parse_var 函数，解析变量
	println('\n\nparse_var line=') // 打印解析变量行
	println('"${line}"') // 打印行
	par_pos := if is_struct { 0 } else { line.index(') ') or { 0 } } // 括号位置
	typ := if is_struct { '' } else { line[1..par_pos] } // 类型
	eq_pos := line.index(' = ') or { 0 } // 等号位置
	name := line[par_pos + 2..eq_pos] // 名称
	// Skip the var if it's no valid yet (not present in the code before the current line) // 如果变量无效（在当前行之前代码中不存在），则跳过
	backtrace := s.before('->').after('stop reason = ') // 回溯
	println('BACKTRACE:') // 打印回溯
	println(backtrace) // 打印回溯
	println('____________________________') // 打印分隔线
	if !backtrace.contains(name) { // 如果回溯不包含名称
		println("SKIPPING ${name} for line '${line}'") // 打印跳过
		return DebuggerVariable{} // 返回空变量
	}
	mut value := line[eq_pos + 3..] // 可变值
	// Get correct string value // 获取正确的字符串值
	if typ == 'string' || (is_struct && value.contains('(str =')) { // 如果是字符串或结构体
		if value.contains('str = 0x0000000000000000') { // 如果包含空字符串
			value = "''" // 设置为空字符串
		} else if value.contains('(str = "') { // 如果包含字符串
			start := value.index('(str =') or { 0 } // 开始位置
			end := value.index(',') or { 0 } // 结束位置
			value = value[start + 6..end] // 设置值
		}
		// Get array contents by callign Array_xxx_str() in lldb // 通过在 lldb 中调用 Array_xxx_str() 获取数组内容
	} else if typ.starts_with('Array_') { // 如果是数组
		elem_type := typ.replace('Array_', '') // 元素类型
		d.send_cmd('p Array_${elem_type}_str(${name})') // 发送命令
		resp := d.wait_for('(string)') or { return DebuggerVariable{} } // 等待响应
		value = resp.after('(string)').after('= "').before('",') // 设置值
	} else if typ == 'bool' { // 如果是布尔
		// Bool // 布尔
		// (bool) bool1 = '\x01'  len=6 TRUE // (bool) bool1 = '\x01'  len=6 TRUE
		//(bool) bool2 = '\0' line=4 FALSE // (bool) bool2 = '\0' line=4 FALSE
		// println('BOOL=${value} len=${value.len}') // （注释）
		// println(int(value[1])) // （注释）
		if value.len == 6 { // 如果长度为6
			value = 'true' // 设置为 true
		} else { // 否则
			value = 'false' // 设置为 false
		}
	} else if typ.starts_with('_option_') { // 如果是选项
		// Option // 选项
		d.send_cmd('p ${typ}_str(${name})') // 发送命令
		resp := d.wait_for('"') or { return DebuggerVariable{} } // 等待响应
		value = resp.after('(str = "').before('", ') // 设置值
	} else if value == '{' { // 如果值是 '{'
		// Struct // 结构体
		struct_code := s.after(line).before('\n}\n') // 结构体代码
		println('STRUCT 1st line:') // 打印结构体第一行
		println(line) // 打印行
		println('STRUCT code:') // 打印结构体代码
		println(struct_code) // 打印结构体代码
		println('============') // 打印分隔线
		// Sum types // 和类型
		if struct_code.contains('_string =') { // 如果包含 '_string ='
			// value = 'sum t:${typ}' // （注释）
			// d.send_cmd('p v_typeof_sumtype_${typ}(${name}._typ)') // （注释）
			d.send_cmd('p ${typ}_str(${name})') // 发送命令
			resp := d.wait_for('"') or { return DebuggerVariable{} } // 等待响应
			value = resp.after('(str = "').before('", ') // 设置值
		} else if struct_code.contains('_object') { // 如果包含 '_object'
			// Interface // 接口
			d.send_cmd('p ${typ}_str(${name})') // 发送命令
			resp := d.wait_for('"') or { return DebuggerVariable{} } // 等待响应
			value = resp.after('(str = "').before('", ') // 设置值
		} else { // 否则
			// Normal struct // 普通结构体
			parsed_struct := d.parse_vars(struct_code, true) // 解析结构体
			println('PARSED STRUCT: ${parsed_struct}') // 打印解析的结构体
			value = parsed_struct.format_struct() // 设置值
		}
	}
	return DebuggerVariable{ // 返回调试器变量
		name:  name // 名称
		typ:   typ.replace('main__', '').replace('Array_', '[]').replace('_option_', '?').replace('__', // 类型替换
		 '.')
		value: value.trim_space() // 值去空格
	}
}

// "next" in lldb // lldb 中的 "next"
fn (mut debugger Debugger) step_over() { // step_over 函数，单步执行
	debugger.send_cmd('next') // 发送 next 命令

	for { // 无限循环
		resp := debugger.wait_for(' stop reason') or { break } // 等待停止原因
		time.sleep(100 * time.millisecond) // 睡眠100毫秒
		// println('2<<<<<<<<<<<<<<<<') // （注释）
		// println(resp) // （注释）
		// println('2>>>>>>>>>>>>>>>>') // （注释）
		debugger.parse_output(resp) // 解析输出
		// d.send_cmd('next') // （注释）
		return
	}
}

fn (mut ved Ved) draw_debugger_variables() { // draw_debugger_variables 函数，绘制调试器变量
	split_from, split_to := ved.get_splits_from_to() // 获取分割从到
	split_width := ved.split_width() // 分割宽度
	// We draw debugger variables in the last split (the one with the output) // 我们在最后一个分割（带有输出的那个）中绘制调试器变量
	last_split_x := split_width * (split_to - 1 - split_from) // 最后分割 x
	// println('split_width=${split_width}, last_split_x=${last_split_x}') // （注释）
	// println('DRAW D VARS x=${last_split_x} splitw=${split_width}, to=${split_to}, from=${split_from}') // （注释）
	ved.gg.draw_rect_filled(last_split_x, ved.cfg.line_height, split_width, 500, ved.cfg.title_color) // 绘制填充矩形
	if ved.debugger.output.vars.len == 0 { // 如果变量长度为0
		return
	}
	x := last_split_x + 3 // x = 最后分割 x + 3
	// Calc first col width // 计算第一列宽度
	max_name_len := 20 // 最大名称长度
	max_value_len := 45 // 最大值长度
	/*
	mut max_len := ved.debugger.output.vars[0].name.len // （注释）
	for var in ved.debugger.output.vars { // （注释）
		if var.name.len > max_len { // （注释）
			max_len = var.name.len // （注释）
		}
	}
	*/
	col_width := (max_name_len + 1) * ved.cfg.char_width // 列宽度
	// Draw the table // 绘制表格
	for i, var in ved.debugger.output.vars { // 遍历变量
		y := (i + 1) * ved.cfg.line_height + 3 // y
		// col_width := 80 // （注释）
		ved.gg.draw_text(x, y, var.name.limit(max_name_len), // 绘制文本
			color: debugger_name_color  // 颜色
			size:  ved.cfg.txt_cfg.size // 大小
		)
		ved.gg.draw_text(x + col_width, y, var.value_fmt(max_value_len), // 绘制文本
			color: gg.white             // 颜色
			size:  ved.cfg.txt_cfg.size // 大小
		)
		ved.gg.draw_text(ved.win_width - col_width, y, var.typ, // 绘制文本
			color: gg.white             // 颜色
			size:  ved.cfg.txt_cfg.size // 大小
		)
	}
}

fn (d DebuggerOutput) format_struct() string { // format_struct 函数，格式化结构体
	mut sb := strings.new_builder(100) // 可变字符串构建器
	sb.write_string('{ ') // 写入 '{ '
	for i, var in d.vars { // 遍历变量
		sb.write_string(var.name) // 写入名称
		sb.write_string(': ') // 写入 ': '
		sb.write_string(var.value) // 写入值
		if i < d.vars.len - 1 { // 如果不是最后一个
			sb.write_string(', ') // 写入 ', '
		}
	}
	sb.write_string(' }') // 写入 ' }'
	return sb.str() // 返回字符串
}

fn (d DebuggerVariable) value_fmt(max_len int) string { // value_fmt 函数，值格式
	if d.value.len > max_len { // 如果值长度 > 最大长度
		return d.value.limit(max_len) + '...' // 返回限制长度 + '...'
	}
	return d.value // 返回值
}
