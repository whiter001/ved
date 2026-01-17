// Copyright (c) 2019-2023 Alexander Medvednikov. All rights reserved. // 版权所有 (c) 2019-2023 Alexander Medvednikov。保留所有权利
// Use of this source code is governed by a GPL license // 本源代码的使用受 GPL 许可证约束
// that can be found in the LICENSE file. // 可在 LICENSE 文件中找到
module main

// 主模块
import os // 导入 os 操作系统库

// For syntax highlighting // 用于语法高亮
enum ChunkKind { // ChunkKind 枚举
	a_string  = 1 // 字符串
	a_comment = 2 // 注释
	a_key     = 3 // 关键字
	a_lit     = 4 // 字面量
}

struct Chunk { // Chunk 结构体
	start int       // 开始
	end   int       // 结束
	typ   ChunkKind // 类型
}

struct Mcomment { // Mcomment 结构体，多行注释
	start string // 开始
	end   string // 结束
}

fn (mut ved Ved) add_chunk(typ ChunkKind, start int, end int) { // add_chunk 函数，添加块
	chunk := Chunk{ // 创建块
		typ:   typ   // 类型
		start: start // 开始
		end:   end   // 结束
	}
	ved.chunks << chunk // 添加到块
}

// Updated to use the new Mcomment struct // 更新为使用新的 Mcomment 结构体
fn get_mcomment_by_ext(ext string) Mcomment { // get_mcomment_by_ext 函数，根据扩展名获取多行注释
	return match ext {
		// 匹配扩展名
		'.html' { // .html
			Mcomment{ // Mcomment
				start: '<!--' // 开始
				end:   '-->'  // 结束
			}
		}
		else { // 其他
			Mcomment{ // Mcomment
				start: '/*' // 开始
				end:   '*/' // 结束
			}
		}
	}
}

// Scans the file content *before* the target line number to determine // 扫描目标行号*之前*的文件内容以确定
// if that target line starts inside an unclosed multiline comment block. // 该目标行是否在未闭合的多行注释块内开始
// Updated to use string-based delimiters. // 更新为使用基于字符串的分隔符
fn (ved &Ved) determine_ml_comment_state(view &View, target_line_nr int) bool { // determine_ml_comment_state 函数，确定多行注释状态
	if target_line_nr <= 0 { // 如果目标行号 <= 0
		return false // First line cannot start inside a comment // 第一行不能在注释内开始
	}
	mcomment := get_mcomment_by_ext(os.file_ext(view.path)) // 获取多行注释
	// State: true = inside comment, false = outside comment // 状态：true = 在注释内，false = 在注释外
	mut is_inside := false // 是否在内部
	// Scan all lines *before* the target line // 扫描目标行*之前*的所有行
	for i := 0; i < target_line_nr; i++ { // 循环
		// Basic bounds check, though shouldn't be needed if target_line_nr is valid // 基本边界检查，如果 target_line_nr 有效则不需要
		if i >= view.lines.len { // 如果 i >= 行长度
			continue // 继续
		}
		line := view.lines[i] // 获取行
		mut k := 0 // k
		// Scan through the characters of the line // 扫描行的字符
		for k < line.len { // 循环
			// Check for start delimiter only if we are *outside* a comment // 仅当我们在注释*外*时检查开始分隔符
			if !is_inside && k + mcomment.start.len <= line.len
				&& line[k..k + mcomment.start.len] == mcomment.start { // 如果不在内部且 k + 开始长度 <= 行长度 且等于开始
				is_inside = true // Enter comment state // 进入注释状态
				k += mcomment.start.len // Skip the delimiter // 跳过分隔符
				continue // 继续
			}
			// Check for end delimiter only if we are *inside* a comment // 仅当我们在注释*内*时检查结束分隔符
			if is_inside && k + mcomment.end.len <= line.len
				&& line[k..k + mcomment.end.len] == mcomment.end { // 如果在内部且 k + 结束长度 <= 行长度 且等于结束
				is_inside = false // Exit comment state // 退出注释状态
				k += mcomment.end.len // Skip the delimiter // 跳过分隔符
				continue // 继续
			}
			// No delimiter found at this position, move to the next character // 此位置未找到分隔符，移动到下一个字符
			k++ // k 加一
		}
	}
	// Return the final state after checking all preceding lines // 检查所有前一行后返回最终状态
	return is_inside // 返回是否在内部
}

// Handles syntax highlighting for a line assuming it does *not* start within a multi-line comment // 处理行的语法高亮，假设它*不*在多行注释内开始
// and does *not* start a multi-line comment that continues to the next line. // 并且*不*开始延续到下一行的多行注释
// It handles single-line comments (//, #), strings, keywords, literals, and single-line /* ... */ or <!-- ... --> comments. // 它处理单行注释（//, #）、字符串、关键字、字面量和单行 /* ... */ 或 <!-- ... --> 注释
fn (mut ved Ved) draw_text_line_standard_syntax(x int, y int, line string, ext string) { // draw_text_line_standard_syntax 函数，绘制标准语法文本行
	mcomment := get_mcomment_by_ext(ext) // 获取多行注释
	// Red/green test hack // 红/绿测试 hack
	/*
       if line.contains('[32m') && line.contains('PASS') { // 如果包含 '[32m' 和 'PASS'
               ved.gg.draw_text(x, y, line[5..], ved.cfg.green_cfg) // 绘制绿色文本
               return // 返回
       } else if line.contains('[31m') && line.contains('FAIL') { // 否则如果包含 '[31m' 和 'FAIL'
               ved.gg.draw_text(x, y, line[5..], ved.cfg.red_cfg) // 绘制红色文本
               return // 返回
       }
       */

	ved.chunks = [] // 清空块
	cur_syntax := ved.syntaxes[ved.current_syntax_idx] or { Syntax{} } // 当前语法
	// TODO use runes for everything to fix keyword + 2+ byte rune words // TODO 为所有内容使用符文以修复关键字 + 2+ 字节符文单词

	mut i := 0 // Use mut i instead of for loop index to allow manual increment // 使用 mut i 而不是 for 循环索引以允许手动递增
	for i < line.len { // 循环
		start := i // 开始
		// Comment // # // 注释
		if i > 0 && line[i - 1] == `/` && line[i] == `/` { // 如果 i > 0 且前一个是 '/' 且当前是 '/'
			ved.add_chunk(.a_comment, start - 1, line.len) // 添加注释块
			i = line.len // End the loop // 结束循环
			break // 跳出
		}
		if line[i] == `#` { // 如果是 '#'
			ved.add_chunk(.a_comment, start, line.len) // 添加注释块
			i = line.len // End the loop // 结束循环
			break // 跳出
		}

		// Single line Comment (e.g., /* ... */ or <!-- ... -->) // 单行注释（例如 /* ... */ 或 <!-- ... -->）
		// Updated to use string-based delimiters. // 更新为使用基于字符串的分隔符
		if i + mcomment.start.len <= line.len && line[i..i + mcomment.start.len] == mcomment.start { // 如果 i + 开始长度 <= 行长度且等于开始
			end_pos := line.index_after(mcomment.end, i + mcomment.start.len) or { -1 } // 结束位置
			if end_pos != -1 { // 如果结束位置 != -1
				ved.add_chunk(.a_comment, start, end_pos + mcomment.end.len) // 添加注释块
				i = end_pos + mcomment.end.len // Move past the comment // 移动到注释后
				continue // 继续
			} else { // 否则
				// This case (start found but no end on this line) should be handled by the new logic in draw_split. // 此情况（找到开始但此行无结束）应由 draw_split 中的新逻辑处理
				// If we reach here, it means draw_split decided this line doesn't start a *continuing* multiline comment. // 如果到达这里，意味着 draw_split 决定此行不开始*延续*的多行注释
				// Treat the start delimiter as normal text by just advancing `i`. // 通过仅推进 `i` 将开始分隔符视为正常文本
				i += 1 // i 加一
				continue // 继续
			}
		}

		// String '...' // 字符串 '...'
		if line[i] == `'` { // 如果是单引号
			mut end := i + 1 // 结束 = i + 1
			for end < line.len && line[end] != `'` { // 循环直到结束或找到单引号
				// Handle escaped quote \' // 处理转义引号 \'
				if line[end] == `\\` && end + 1 < line.len && line[end + 1] == `'` { // 如果是转义
					end++ // Skip escaped quote // 跳过转义引号
				}
				end++ // 结束加一
			}
			if end >= line.len { // 如果结束 >= 行长度
				end = line.len - 1 // 结束 = 行长度 - 1
			} else { // 否则
				end += 1 // include closing quote // 包括闭合引号
			}
			ved.add_chunk(.a_string, start, end) // 添加字符串块
			if i == end { // 如果 i == 结束
				i++ // i 加一
			} else { // 否则
				i = end // Move past the string // 移动到字符串后
			}
			continue // 继续
		}
		// String "..." // 字符串 "..."
		if line[i] == `"` { // 如果是双引号
			mut end := i + 1 // 结束 = i + 1
			for end < line.len && line[end] != `"` { // 循环直到结束或找到双引号
				// Handle escaped quote \" // 处理转义引号 \"
				if line[end] == `\\` && end + 1 < line.len && line[end + 1] == `"` { // 如果是转义
					end++ // Skip escaped quote // 跳过转义引号
				}
				end++ // 结束加一
			}
			if end >= line.len { // 如果结束 >= 行长度
				end = line.len - 1 // 结束 = 行长度 - 1
			} else { // 否则
				end += 1 // include closing quote // 包括闭合引号
			}
			ved.add_chunk(.a_string, start, end) // 添加字符串块
			if i == end { // 如果 i == 结束
				i++ // i 加一
			} else { // 否则
				i = end // Move past the string // 移动到字符串后
			}
			continue // 继续
		}
		// Key // 关键字
		if is_alpha_underscore(int(line[i])) { // 如果是字母下划线
			mut end := i + 1 // 结束 = i + 1
			for end < line.len && is_alpha_underscore(int(line[end])) { // 循环直到结束或非字母下划线
				end++ // 结束加一
			}
			word := line[start..end] // 单词
			if word in cur_syntax.literals { // 如果在字面量中
				ved.add_chunk(.a_lit, start, end) // 添加字面量块
			} else if word in cur_syntax.keywords { // 否则如果在关键字中
				ved.add_chunk(.a_key, start, end) // 添加关键字块
			}
			// If it's not a keyword or literal, it will be drawn as normal text later. // 如果不是关键字或字面量，稍后将作为正常文本绘制
			if i == end { // 如果 i == 结束
				i++ // i 加一
			} else { // 否则
				i = end // Move past the word // 移动到单词后
			}
			continue // 继续
		}

		// If none of the above matched, advance by one character // 如果以上均不匹配，前进一个字符
		i++ // i 加一
	}

	// --- Keep the original chunk drawing logic --- // --- 保留原始块绘制逻辑 ---
	if ved.chunks.len == 0 { // 如果块长度为 0
		ved.gg.draw_text(x, y, line, ved.cfg.txt_cfg) // 绘制文本
		return
	}
	mut pos := 0 // 位置
	mut cur_x := x // 当前 x
	// println('"$line" nr chunks=$ved.chunks.len') // 打印块数量
	for j, chunk in ved.chunks { // 循环块
		if chunk.start > pos { // 如果块开始 > 位置
			s := line[pos..chunk.start] // 字符串
			ved.gg.draw_text(cur_x, y, s, ved.cfg.txt_cfg) // 绘制文本
			cur_x += ved.text_width_tabs(s) // 当前 x 增加
		}
		typ := chunk.typ // 类型
		cfg := match typ {
			// 匹配类型
			.a_key { ved.cfg.key_cfg } // 关键字配置
			.a_lit { ved.cfg.lit_cfg } // 字面量配置
			.a_string { ved.cfg.string_cfg } // 字符串配置
			.a_comment { ved.cfg.comment_cfg } // 注释配置
		}
		s := line[chunk.start..chunk.end] // 字符串
		ved.gg.draw_text(cur_x, y, s, cfg) // 绘制文本
		cur_x += ved.text_width_tabs(s) // 当前 x 增加
		pos = chunk.end // 位置 = 块结束
		if j == ved.chunks.len - 1 && pos < line.len { // 如果是最后一个块且位置 < 行长度
			final := line[pos..] // 最终字符串
			ved.gg.draw_text(cur_x, y, final, ved.cfg.txt_cfg) // 绘制最终文本
		}
	}
	// --- End of original chunk drawing logic --- // --- 原始块绘制逻辑结束 ---
}
