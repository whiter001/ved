// Copyright (c) 2019 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by a GPL license
// that can be found in the LICENSE file.
module main

import os
import gg
// import toml
import x.json2

// The different kinds of cursors
// 光标的不同类型
enum Cursor {
	block    // 块状
	beam     // 条状
	variable // 可变
}

// Config structure
// TODO: Load user config from file
// 配置结构体
// TODO: 从文件加载用户配置
struct Config {
mut:
	// settings        toml.Doc
	dark_mode       bool   // 深色模式
	cursor_style    Cursor // 光标样式
	text_size       int = min_text_size // 文本大小
	line_height     int = 20            // 行高
	char_width      int = 8             // 字符宽度
	tab_size        int = 4             // 制表符大小
	tab             int = int(`\x09`)   // 制表符字符
	backspace_go_up bool     // 退格键是否可向上换行
	vcolor          gg.Color // 可视模式选择区域背景颜色
	split_color     gg.Color // 分屏线颜色
	bgcolor         gg.Color // 编辑器背景颜色 (base00)
	errorbgcolor    gg.Color // 错误行背景颜色 (base08)
	title_color     gg.Color // 标题颜色 (base04)
	cursor_color    gg.Color // 光标颜色 (base05)
	string_color    gg.Color // 字符串颜色 (base0B)
	string_cfg      gg.TextCfg
	key_color       gg.Color // 关键字颜色 (base0E)
	key_cfg         gg.TextCfg
	lit_color       gg.Color // 字面量颜色 (base0E)
	lit_cfg         gg.TextCfg
	text_color      gg.Color // 普通文本颜色 (base05)
	txt_cfg         gg.TextCfg
	comment_color   gg.Color // 注释颜色 (base03)
	comment_cfg     gg.TextCfg
	file_name_color gg.Color // 文件名颜色
	file_name_cfg   gg.TextCfg
	plus_color      gg.Color // Git 新增行颜色
	plus_cfg        gg.TextCfg
	minus_color     gg.Color // Git 删除行颜色
	minus_cfg       gg.TextCfg
	line_nr_color   gg.Color // 行号颜色 (base01)
	line_nr_cfg     gg.TextCfg
	green_color     gg.Color // 绿色 (base0B)
	green_cfg       gg.TextCfg
	red_color       gg.Color // 红色 (base08)
	red_cfg         gg.TextCfg
	disable_mouse   bool // 是否禁用鼠标
	show_file_tree  bool // 是否显示文件树

	// Config.json
	disable_fmt bool // 是否禁用格式化
}

// reload_config reloads the config from config.toml file
// set_default_color_values?
// set_default_values 设置配置的默认值
fn (mut config Config) set_default_values() {
	config.init_colors()

	config.set_cursor_style()
	config.set_vcolor()
	config.set_split()
	config.set_bgcolor()
	config.set_errorbgcolor()
	config.set_string()
	config.set_key()
	config.set_lit()
	config.set_title()
	config.set_cursor()
	config.set_txt()
	config.set_comment()
	config.set_filename()
	config.set_plus()
	config.set_minus()
	config.set_line_nr()
	config.set_green()
	config.set_red()
}

// init_colors 初始化颜色模式（如检查命令行参数中的深色模式）
fn (mut config Config) init_colors() {
	config.dark_mode ||= '-dark' in os.args
}

// set_cursor_style 设置光标样式，默认为条状
fn (mut config Config) set_cursor_style() {
	config.cursor_style = .beam
}

// set_vcolor 设置可视模式下的选择颜色
fn (mut config Config) set_vcolor() {
	if !config.dark_mode {
		config.vcolor = gg.rgb(226, 233, 241)
	} else {
		config.vcolor = gg.rgb(60, 60, 60)
	}
}

// set_split 设置分屏边界线的颜色
fn (mut config Config) set_split() {
	if !config.dark_mode {
		config.split_color = gg.rgb(223, 223, 223)
	} else {
		config.split_color = gg.rgb(50, 50, 50)
	}
}

// set_bgcolor 设置背景颜色 (对应 base 00)
fn (mut config Config) set_bgcolor() {
	config.bgcolor = if config.dark_mode {
		gg.rgb(30, 30, 30)
	} else {
		gg.rgb(245, 245, 245)
	}
}

// set_errorbgcolor 设置错误高亮的背景颜色 (对应 base 01)
fn (mut config Config) set_errorbgcolor() {
	config.errorbgcolor = gg.rgb(240, 0, 0)
}

// set_string 设置字符串的高亮颜色 (对应 base 0B)
fn (mut config Config) set_string() {
	config.string_color = gg.rgb(179, 58, 44)
	config.string_cfg = gg.TextCfg{
		size:  config.text_size
		color: config.string_color
	}
}

// set_key 设置关键字的高亮颜色 (对应 base 0E)
fn (mut config Config) set_key() {
	config.key_color = gg.rgb(74, 103, 154)

	config.key_cfg = gg.TextCfg{
		size:  config.text_size
		color: config.key_color
	}
}

// set_lit 设置字面量的高亮颜色 (对应 base 0F)
fn (mut config Config) set_lit() {
	config.lit_color = gg.rgb(7, 103, 154)

	config.lit_cfg = gg.TextCfg{
		size:  config.text_size
		color: config.lit_color
	}
}

// set_title 设置标题颜色 (对应 base 04)
fn (mut config Config) set_title() {
	config.title_color = gg.rgb(0, 0, 0)
}

// set_cursor 设置光标本身的颜色 (对应 base 05)
fn (mut config Config) set_cursor() {
	config.cursor_color = if !config.dark_mode {
		gg.black
	} else {
		gg.white
	}
}

// set_txt 设置普通文本的颜色 (对应 base 05)
fn (mut config Config) set_txt() {
	config.text_color = if !config.dark_mode {
		gg.black
	} else {
		gg.rgb(212, 212, 212)
	}

	config.txt_cfg = gg.TextCfg{
		size:  config.text_size
		color: config.text_color
	}
}

// set_comment 设置注释颜色 (对应 base 03)
fn (mut config Config) set_comment() {
	config.comment_color = gg.dark_gray

	config.comment_cfg = gg.TextCfg{
		size:  config.text_size
		color: config.comment_color
	}
}

// set_filename 设置顶部文件名的显示颜色
fn (mut config Config) set_filename() {
	config.file_name_color = gg.white
	config.file_name_cfg = gg.TextCfg{
		size:  config.text_size
		color: config.file_name_color
	}
}

// set_plus 设置 Git 新增行的标识颜色
fn (mut config Config) set_plus() {
	config.plus_color = gg.green
	config.plus_cfg = gg.TextCfg{
		size:  config.text_size
		color: config.plus_color
	}
}

// set_minus 设置 Git 删除行的标识颜色
fn (mut config Config) set_minus() {
	config.minus_color = gg.green
	config.minus_cfg = gg.TextCfg{
		size:  config.text_size
		color: config.minus_color
	}
}

// set_line_nr 设置侧边行号的颜色 (对应 base 01)
fn (mut config Config) set_line_nr() {
	config.line_nr_color = gg.dark_gray

	config.line_nr_cfg = gg.TextCfg{
		size:  config.text_size
		color: config.line_nr_color
		align: gg.align_right
	}
}

// set_green 设置通用的绿色配置
fn (mut config Config) set_green() {
	config.green_color = gg.green

	config.green_cfg = gg.TextCfg{
		size:  config.text_size
		color: config.green_color
	}
}

// set_red 设置通用的红色配置
fn (mut config Config) set_red() {
	config.red_color = gg.red
	config.red_cfg = gg.TextCfg{
		size:  config.text_size
		color: config.red_color
	}
}

// load_config2 从 JSON 文件加载持久化的配置
fn (mut ved Ved) load_config2() {
	if os.exists(config_path2) {
		if conf2 := json2.decode[Config](os.read_file(config_path2) or { return }) {
			println('从 ${config_path2} 加载配置: ${conf2}')
			ved.cfg = conf2
		} else {
			println(err)
		}
	}
	ved.cfg.set_default_values()
}

// save_config2 将当前配置保存到 JSON 文件
fn (mut ved Ved) save_config2() {
	os.write_file(config_path2, json2.encode(ved.cfg, prettify: true)) or { panic(err) }
}
