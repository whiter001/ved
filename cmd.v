// Copyright (c) 2019 Alexander Medvednikov. All rights reserved. // 版权所有 (c) 2019 Alexander Medvednikov。保留所有权利
// Use of this source code is governed by a GPL license // 本源代码的使用受 GPL 许可证约束
// that can be found in the LICENSE file. // 可在 LICENSE 文件中找到
module main // 主模块

// This file contains logic related to running external commands (building projects, // 此文件包含运行外部命令的逻辑（构建项目，
// running files, running zsh commands) // 运行文件，运行 zsh 命令）
import os // 导入 os 操作系统库

fn (mut ved Ved) build_app1() { // build_app1 函数，构建应用1
	ved.build_app('') // 构建应用
	// ved.next_split() // （注释）
	// glfw.post_empty_event() // （注释）
	// ved.prev_split() // （注释）
	// glfw.post_empty_event() // （注释）
	// ved.refresh = false // （注释）
}

fn (mut ved Ved) build_app2() { // build_app2 函数，构建应用2
	ved.build_app('2') // 构建应用 '2'
}

fn (mut ved Ved) build_app(extra string) { // build_app 函数，构建应用
	eprintln('build_app: ${extra}') // 错误打印
	ved.is_building = true // is_building = true
	// Save each open file before building // 构建前保存每个打开的文件
	ved.save_changed_files() // 保存更改的文件
	os.chdir(ved.workspace) or { return } // 改变目录
	dir := ved.workspace // 目录
	mut build_file := ved.get_build_file_location() or { return } // 获取构建文件位置
	if extra != '' { // 如果额外不为空
		build_file += extra // 添加额外
	}

	out_file := os.join_path(dir, 'out') // 输出文件
	building_cmd := 'sh ${build_file}' // 构建命令
	eprintln('building with `${building_cmd}` ...') // 错误打印

	last_view_idx := ved.last_view_idx() // 最后视图索引

	os.write_file(out_file, 'Building...') or { panic(err) } // 写入文件
	ved.views[last_view_idx].open_file(out_file, 0) // 打开文件

	out := os.execute(building_cmd) // 执行命令
	if out.exit_code == -1 { // 如果退出码为 -1
		return // 返回
	}

	os.write_file(out_file, filter_ascii_colors(out.output)) or { panic(err) } // 写入文件
	ved.views[last_view_idx].open_file(out_file, 0) // 打开文件

	ved.views[last_view_idx].shift_g() // 移动到最后视图的 g 位置
	// error line // 错误行
	lines := out.output.split_into_lines() // 将输出分割成行
	println('lines=${lines}') // 打印行数
	// lines := alines.filter(it.contains('.v:') || it.contains('.go:')) // （注释）
	mut no_errors := true // !out.output.contains('error:') // 无错误 = true
	for line in lines { // 遍历行
		// no "warning:" in a line means it's an error // 行中没有 "warning:" 意味着是错误
		if !line.contains('warning:') { // 如果不包含 'warning:'
			no_errors = false // 无错误 = false
		}
	}
	println('no_errors=${no_errors}') // 打印无错误
	mut i := 0 // i = 0
	for _, line in lines { // 遍历行
		if !line.contains('.v:') && !line.contains('.go:') { // 如果不包含 '.v:' 或 '.go:'
			println('skip1 ${line}') // 打印跳过1
			i++ // i++
			continue // 继续
		}
		is_warning := line.contains('warning:') // 是警告
		is_notice := line.contains('notice:') // 是通知
		is_error := line.contains('error:') // 是错误
		if !is_warning && !is_notice && !is_error { // 如果不是警告、通知或错误
			println('skip2 ${line}') // 打印跳过2
			i++ // i++
			continue // 继续
		}
		println('${i}, HANDLE E LINE ${line}') // 打印处理错误行
		// Go to the next warning only if there are no errors. // 只有在没有错误时才转到下一个警告
		// This makes Ved go to errors before warnings. // 这使 Ved 在警告之前转到错误
		if is_error && ((!is_notice && !is_warning) || (is_warning && no_errors) // 如果是错误且条件满足
			|| (is_notice && no_errors)) {
			mut error_details := '' // 错误详情 = ''
			for i < lines.len - 1 { // 循环
				if lines[i].contains('Details') { // 如果包含 'Details'
					error_details += lines[i] // 添加错误详情
					if i + 1 < lines.len { // 如果 i+1 < 长度
						error_details += lines[i + 1] // 添加下一行
						break // 跳出
					}
				}
				i++ // i++
			}
			// next_line := if i < lines.len - 1 { lines[i + 1] } else { '' } // （注释）
			ved.go_to_error(line, error_details) // 转到错误
			break // 跳出
		}
	}
	ved.refresh = true // 刷新 = true
	ved.gg.refresh_ui() // 刷新 UI
	// ved.refresh = true // （注释）
	// time.sleep(4) // delay is_building to prevent flickering in the right split // （注释）
	ved.is_building = false // is_building = false
	// Move to the first line of the output in the last view, so that it's // 移动到最后视图输出的第一行，以便始终可见
	// always visible // 始终可见
	ved.views[last_view_idx].from = 0 // from = 0
	ved.views[last_view_idx].set_y(0) // 设置 y = 0
	/*
	// Reopen files (they were formatted) // 重新打开文件（它们已被格式化）
	for _view in ved.views { // 遍历视图
		// ui.alert('reopening path') // （注释）
		mut view := _view // 可变视图
		println(view.path) // 打印路径
		view.open_file(view.path) // 打开文件
	}
	*/
}

// Run file in current view (go run [file], v run [file], python [file] etc) // 运行当前视图中的文件（go run [file]，v run [file]，python [file] 等）
// Saves time for user since they don't have to define 'build' for every file // 为用户节省时间，因为他们不必为每个文件定义 'build'
fn (mut ved Ved) run_file() { // run_file 函数
	mut view := ved.view // 可变视图
	ved.error_line = '' // 错误行 = ''
	ved.is_building = true // is_building = true
	// println('start file run') // （注释）
	// Save the file before building // 构建前保存文件
	if view.changed { // 如果更改
		view.save_file() // 保存文件
	}
	// go run /a/b/c.go // go run /a/b/c.go
	// dir is "/a/b/" // dir 是 "/a/b/"
	// cd to /a/b/ // cd 到 /a/b/
	// dir := ospath.dir(view.path) // （注释）
	dir := os.dir(view.path) // 目录
	os.chdir(dir) or {} // 改变目录
	out := os.execute('v run ${view.path}') // 执行 'v run'
	os.write_file('${dir}/out', out.output) or { panic(err) } // 写入文件
	// TODO COPYPASTA // TODO 复制粘贴
	mut last_view := ved.get_last_view() // 最后视图
	last_view.open_file('${dir}/out', 0) // 打开文件
	last_view.shift_g() // 移动 g
	ved.is_building = false // is_building = false
	// error line // 错误行
	lines := out.output.split_into_lines() // 分割行
	for line in lines { // 遍历行
		if line.contains('.v:') || line.contains('.go:') { // 如果包含 '.v:' 或 '.go:'
			ved.go_to_error(line, '') // 转到错误
			break // 跳出
		}
	}
	ved.refresh = true // 刷新 = true
	ved.gg.refresh_ui() // 刷新 UI
}

fn (ved &Ved) run_zsh() { // run_zsh 函数
	text := ved.query // 文本
	dir := ved.workspace // 目录
	os.chdir(dir) or { return } // 改变目录
	res := os.execute('zsh -ic "source ~/.zshrc; ${text}" > ${dir}/out') // 执行 zsh
	if res.exit_code == -1 { // 如果退出码为 -1
	}
	// TODO copypasted some code from build_app() // TODO 从 build_app() 复制了一些代码
	// mut f2 := os.create('$dir/out') or { panic('fail') } // （注释）
	// f2.writeln(out.output) or { panic(err) } // （注释）
	// f2.close() // （注释）
	mut last_view := ved.get_last_view() // 最后视图
	last_view.open_file('${dir}/out', 0) // 打开文件
}
