// Copyright (c) 2019-2025 Alexander Medvednikov. All rights reserved. // 版权所有 (c) 2019-2025 Alexander Medvednikov。保留所有权利
// Use of this source code is governed by a GPL license // 本源代码的使用受 GPL 许可证约束
// that can be found in the LICENSE file. // 可在 LICENSE 文件中找到
module main

// 主模块
import strings // 导入 strings 字符串库

// Fit lines  into 80 chars // 将行调整为 80 个字符
// gq reflows (formats) the visually selected paragraph to a fixed width. (Vim: `gq`) // gq 重新流动（格式化）视觉选择的段落到固定宽度（Vim: `gq`）
fn (mut view View) gq() { // gq 函数，格式化
	mut ved := view.ved // 获取 ved
	if ved.mode != .visual { // 如果模式不是视觉
		return
	}

	vtop, vbot := if view.vstart < view.vend { // 如果 vstart < vend
		view.vstart, view.vend // vtop, vbot
	} else { // 否则
		view.vend, view.vstart // vtop, vbot
	}
	if vtop < 0 || vbot < 0 || vtop >= view.lines.len || vbot >= view.lines.len { // 如果边界无效
		ved.exit_visual() // 退出视觉模式
		return
	}

	mut selected_lines := []string{} // 选择的行
	for i := vtop; i <= vbot; i++ { // 循环选择的行
		selected_lines << view.lines[i] // 添加行
	}

	if selected_lines.len == 0 { // 如果选择的行长度为 0
		ved.exit_visual() // 退出视觉模式
		return
	}

	// Preserve indentation from the first line of the selection. // 保留选择第一行的缩进
	first_line := selected_lines[0] // 第一行
	indent_str := first_line[..first_line.len - first_line.trim_left(' \t').len] // 缩进字符串

	// Combine selected lines into a single string, preserving paragraph breaks (empty lines). // 将选择的行组合成单个字符串，保留段落分隔（空行）
	mut paragraphs := []string{} // 段落
	mut current_paragraph := strings.new_builder(1024) // 当前段落
	for line in selected_lines { // 循环选择的行
		trimmed_line := line.trim_space() // 修剪行
		if trimmed_line.len == 0 { // 如果修剪行长度为 0
			if current_paragraph.len > 0 { // 如果当前段落长度 > 0
				paragraphs << current_paragraph.str() // 添加段落
				unsafe { // 不安全
					current_paragraph.reset() // 重置
				}
			}
			paragraphs << '' // Represents a blank line // 表示空行
		} else { // 否则
			if current_paragraph.len > 0 { // 如果当前段落长度 > 0
				current_paragraph.write_string(' ') // 写入空格
			}
			current_paragraph.write_string(trimmed_line) // 写入修剪行
		}
	}
	if current_paragraph.len > 0 { // 如果当前段落长度 > 0
		paragraphs << current_paragraph.str() // 添加段落
	}

	// Delete the original selected lines. // 删除原始选择的行
	for i := 0; i < selected_lines.len; i++ { // 循环
		view.lines.delete(vtop) // 删除行
	}

	// Reflow each paragraph and build the final list of new lines. // 重新流动每个段落并构建新行列表
	max_width := 79 // 最大宽度
	reflow_width := max_width - indent_str.runes().len // 重新流动宽度

	mut new_lines := []string{} // 新行
	for para in paragraphs { // 循环段落
		if para == '' { // 如果段落为空
			new_lines << indent_str.trim_right(' \t') // 添加空行
		} else { // 否则
			reflowed_para := reflow_text_word_aware(para, if reflow_width > 10 { // 重新流动段落
				reflow_width // 重新流动宽度
			} else { // 否则
				10 // 10
			})
			for line in reflowed_para { // 循环重新流动的行
				new_lines << indent_str + line // 添加新行
			}
		}
	}

	// Insert the new, reflowed lines back into the buffer one by one. // 将新的重新流动的行逐一插入缓冲区
	mut insert_pos := if vtop > view.lines.len { view.lines.len } else { vtop } // 插入位置
	for line in new_lines { // 循环新行
		if insert_pos > view.lines.len { // Should not happen, but a safeguard // 不应该发生，但作为保护措施
			view.lines << line // 添加行
		} else { // 否则
			view.lines.insert(insert_pos, line) // 插入行
		}
		insert_pos++ // 插入位置加一
	}

	// Reset cursor and mode. // 重置光标和模式
	view.set_y(vtop) // 设置 y
	view.x = indent_str.runes().len // 设置 x
	ved.exit_visual() // 退出视觉模式
	view.changed = true // 已更改
}

fn reflow_text_word_aware(text string, width int) []string { // reflow_text_word_aware 函数，词感知重新流动文本
	mut lines := []string{} // 行
	// Normalize newlines and whitespace, then split into words. // 规范化换行符和空白，然后分割成单词
	words := text.replace('\n', ' ').split(' ').filter(it.len > 0) // 单词

	if words.len == 0 { // 如果单词长度为 0
		return lines // 返回行
	}

	mut current_line := strings.new_builder(width) // 当前行

	for word in words { // 循环单词
		// If the current line is empty, just add the word. // 如果当前行为空，只添加单词
		if current_line.len == 0 { // 如果当前行长度为 0
			current_line.write_string(word) // 写入单词
			// If adding the word (with a space) fits, add it. // 如果添加单词（带空格）合适，添加它
		} else if current_line.len + 1 + word.len <= width { // 如果当前行长度 + 1 + 单词长度 <= 宽度
			current_line.write_string(' ') // 写入空格
			current_line.write_string(word) // 写入单词
			// Otherwise, finish the current line and start a new one with the word. // 否则，完成当前行并以单词开始新行
		} else { // 否则
			lines << current_line.str() // 添加行
			unsafe { // 不安全
				current_line.reset() // 重置
			}
			current_line.write_string(word) // 写入单词
		}
	}

	// Add the last line if it has content. // 如果有内容，添加最后一行
	if current_line.len > 0 { // 如果当前行长度 > 0
		lines << current_line.str() // 添加行
	}

	return lines // 返回行
}
