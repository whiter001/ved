// Copyright (c) 2019 Alexander Medvednikov. All rights reserved. // 版权所有 (c) 2019 Alexander Medvednikov。保留所有权利
// Use of this source code is governed by a GPL license // 本源代码的使用受 GPL 许可证约束
// that can be found in the LICENSE file. // 可在 LICENSE 文件中找到
module main

// 主模块
import os // 导入 os 操作系统库
import x.json2 // 导入 x.json2 JSON 库

const builtin_v_syntax_file_content = $embed_file('syntax/v.syntax').to_string() // 内置 V 语法文件内容

struct Syntax { // Syntax 结构体
	name       string   // 名称
	extensions []string // 扩展名
	fmt_cmd    string   // 格式命令
	keywords   []string // 关键字
	literals   []string // 字面量
}

fn (mut ved Ved) load_syntaxes() { // load_syntaxes 函数，加载语法
	if !ved.is_test {
		println('loading syntax files...') // 打印加载语法文件
	}
	vsyntax := json2.decode[Syntax](builtin_v_syntax_file_content) or { // 解码内置 V 语法
		panic('the builtin syntax file "${builtin_v_syntax_file_content}" can not be decoded ${err}') // 恐慌
	}
	ved.syntaxes << vsyntax // 添加 V 语法
	files := os.walk_ext(syntax_dir, '.syntax') // 遍历语法文件
	for file in files { // 循环文件
		fcontent := os.read_file(file) or { // 读取文件内容
			eprintln('    error: cannot load syntax file ${file}: ${err.msg()}') // 错误打印
			'{}' // '{}'
		}
		syntax := json2.decode[Syntax](fcontent) or { // 解码语法
			eprintln('    error: cannot load syntax file ${file}: ${err.msg()}') // 错误打印
			Syntax{} // Syntax{}
		}
		if file.ends_with('v.syntax') { // 如果以 v.syntax 结尾
			// allow overriding the builtin embedded syntax at runtime: // 允许在运行时覆盖内置嵌入语法
			ved.syntaxes[0] = syntax // 设置语法
			continue // 继续
		}
		ved.syntaxes << syntax // 添加语法
	}
	if !ved.is_test {
		println('${files.len} syntax files loaded + the compile time builtin syntax for .v') // 打印加载的语法文件数量
	}
}

fn (mut ved Ved) set_current_syntax_idx(ext string) { // set_current_syntax_idx 函数，设置当前语法索引
	for i, syntax in ved.syntaxes { // 循环语法
		if ext in syntax.extensions { // 如果扩展名在语法扩展名中
			if !ved.is_test {
				println('selected syntax ${syntax.name} for extension ${ext}') // 打印选择的语法
			}
			ved.current_syntax_idx = i // 设置当前语法索引
			break // 跳出
		}
	}
}
