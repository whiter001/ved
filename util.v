module main

// 主模块

fn nr_spaces_and_tabs_in_line(line string) (int, int) { // nr_spaces_and_tabs_in_line 函数，计算行中的空格和制表符数量
	mut nr_spaces := 0 // 可变空格数量 = 0
	mut nr_tabs := 0 // 可变制表符数量 = 0
	mut i := 0 // 可变 i = 0
	for i < line.len && (line[i] == ` ` || line[i] == `\t`) { // 当 i < 长度且是空格或制表符
		if line[i] == ` ` { // 如果是空格
			nr_spaces++ // 空格数量++
		}
		if line[i] == `\t` { // 如果是制表符
			nr_tabs++ // 制表符数量++
		}
		i++ // i++
	}
	return nr_spaces, nr_tabs // 返回空格数量，制表符数量
}

// rune_width returns the visual width of a rune (1 for ASCII, 2 for CJK/wide characters). // rune_width 返回符文的视觉宽度（ASCII 为1，CJK/宽字符为2）
fn rune_width(r rune) int { // rune_width 函数
	if int(r) < 128 { // 如果 int(r) < 128
		return 1 // 返回1
	}
	// Basic CJK Unified Ideographs range // 基本 CJK 统一表意文字范围
	if int(r) >= 0x4E00 && int(r) <= 0x9FFF { // 如果在范围内
		return 2 // 返回2
	}
	// Fullwidth forms etc. // 全宽形式等
	if int(r) >= 0xFF00 && int(r) <= 0xFFEF { // 如果在范围内
		return 2 // 返回2
	}
	return 1 // 返回1
}

// string_width returns the total visual width of a string. // string_width 返回字符串的总视觉宽度
fn string_width(s string) int { // string_width 函数
	mut width := 0 // 可变宽度 = 0
	runes := s.runes() // 符文
	for r in runes { // 遍历符文
		width += rune_width(r) // 宽度 += 符文宽度
	}
	return width // 返回宽度
}

// normalize_punctuation converts CJK full-width punctuation to ASCII equivalents
fn normalize_punctuation(s string) string {
	return match s {
		'（' { '(' }
		'）' { ')' }
		'【' { '[' }
		'】' { ']' }
		'《' { '<' }
		'》' { '>' }
		'“', '”' { '"' }
		'‘', '’' { "'" }
		'。' { '.' }
		'，' { ',' }
		'；' { ';' }
		'：' { ':' }
		'！' { '!' }
		'？' { '?' }
		'—' { '-' } // Em-dash to hyphen
		else { s }
	}
}
