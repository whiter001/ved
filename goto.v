module main // 主模块

import os // 导入 os 操作系统库

// gd // gd
fn (mut ved Ved) go_to_def() { // go_to_def 函数，跳转到定义
	word := ved.word_under_cursor() // 获取光标下单词
	// println('GD "$word"') // 打印 GD 信息（注释）
	queries := [') ${word}(', 'fn ${word}('] // 查询列表
	mut view := ved.view // 获取视图
	for query in queries { // 循环查询
		for i, line in view.lines { // 循环行
			if line.contains(query) { // 如果包含查询
				ved.move_to_line(i) // 移动到行
				return // 返回
			}
		}
	}
	// Not found in current file, try all files in the git tree // 当前文件未找到，尝试 git 树中的所有文件
	if ved.all_git_files.len == 0 { // 如果所有 git 文件长度为 0
		// ctrl p not pressed, force to generate all git files list // 未按 ctrl p，强制生成所有 git 文件列表
		ved.load_git_tree() // 加载 git 树
	}
	for query in queries { // 循环查询
		for file_ in ved.all_git_files { // 循环文件
			mut file := file_.to_lower() // 转为小写
			file = file.trim_space() // 修剪空格
			if !file.ends_with('.v') { // 如果不以 .v 结尾
				continue // 继续
			}
			file = '${ved.workspace}/${file}' // 文件路径
			lines := os.read_lines(file) or { continue } // 读取行
			// println('trying file $file with $lines.len lines') // 打印尝试文件（注释）
			for j, line in lines { // 循环行
				if line.contains(query) { // 如果包含查询
					view.open_file(file, j) // 打开文件
					// ved.move_to_line(j) // 移动到行（注释）
					return // 返回
				}
			}
		}
	}
}

// Implements the `[[` command, moving the cursor to the start of the current or preceding function definition. // 实现 `[[` 命令，将光标移动到当前或前一个函数定义的开始
fn (mut ved Ved) go_to_fn_start() { // go_to_fn_start 函数，跳转到函数开始
	mut view := ved.view // 获取视图
	// Start checking from the line *above* the current cursor position // 从当前光标位置*上方*的行开始检查
	mut current_line_nr := view.y - 1 // 当前行号

	for current_line_nr >= 0 { // 当当前行号 >= 0
		// Ensure we don't access an invalid index if the file is empty or near the beginning // 确保如果文件为空或接近开头时不访问无效索引
		if current_line_nr < view.lines.len { // 如果当前行号 < 行长度
			line := view.lines[current_line_nr] // 获取行
			// Check if the line starts with "fn " (V function definition) // 检查行是否以 "fn " 开始（V 函数定义）
			// TODO: Potentially add checks for other languages like Go ("func ") if needed // TODO：如果需要，可能添加对其他语言的检查，如 Go ("func ")
			if line.starts_with('fn ') { // 如果以 'fn ' 开始
				ved.move_to_line(current_line_nr) // 移动到行
				view.zz() // Center the view on the found function // 将视图居中在找到的函数上
				return // 返回
			}
		}
		current_line_nr-- // 当前行号减一
	}
	// If no function start is found above, potentially move to the top of the file or do nothing. // 如果上面未找到函数开始，可能移动到文件顶部或什么都不做
	// Current behavior: do nothing if no function found above. // 当前行为：如果上面未找到函数，什么都不做
}
