// Copyright (c) 2019-2023 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by a GPL license
// that can be found in the LICENSE file.
module main

// 主模块
import gg // 图形库
import os // 操作系统相关功能
import time // 时间处理
import uiold // 旧版 UI 库
import clipboard // 剪贴板功能
import x.json2 // JSON 解析库

// 来自 C 的 IME 输入回调函数
fn ved_insert_text(ved_ptr voidptr, text &char) {
	s := unsafe { text.vstring() } // 将 C 字符串转换为 V 字符串
	if s.len > 0 {
		mut ved := unsafe { &Ved(ved_ptr) } // 获取 Ved 实例指针
		match s {
			// 根据输入文本执行相应操作
			'[ENTER]' {
				ved.view.enter() // 插入换行
			}
			'[BACKSPACE]' {
				ved.view.backspace() // 删除字符
			}
			'[ESC]' {
				ved.exit_visual() // 退出可视模式
			}
			'[TAB]' {
				ved.view.insert_text('\t') // 插入制表符
			}
			'[UP]' {
				ved.view.k() // 向上移动
			}
			'[DOWN]' {
				ved.view.j() // 向下移动
			}
			'[LEFT]' {
				ved.view.h() // 向左移动
			}
			'[RIGHT]' {
				ved.view.l() // 向右移动
			}
			'[HOME]' {
				ved.view.x = 0 // 移动到行首
			}
			'[END]' {
				ved.view.x = ved.view.line().len // 移动到行尾
			}
			'[PGUP]' {
				ved.view.shift_b() // 向上翻页
			}
			'[PGDN]' {
				ved.view.shift_f() // 向下翻页
			}
			else {
				if ved.mode == .insert || ved.mode == .autocomplete {
					ved.view.insert_text(s) // 插入文本
				}
			}
		}
		ved.marked_text = '' // 清空标记文本
		ved.refresh = true // 设置刷新标志
		ved.gg.refresh_ui() // 刷新 UI
	}
}

// IME 标记文本回调函数
fn ved_marked_text(ved_ptr voidptr, text &char) {
	s := unsafe { text.vstring() } // 将 C 字符串转换为 V 字符串
	mut ved := unsafe { &Ved(ved_ptr) } // 获取 Ved 实例指针
	ved.marked_text = s // 设置标记文本
	ved.refresh = true // 设置刷新标志
	ved.gg.refresh_ui() // 刷新 UI
}

// 常量定义：各种路径和设置
const exe_dir = os.dir(os.executable()) // 可执行文件目录
const home_dir = os.home_dir() // 用户主目录
const settings_dir = os.join_path(home_dir, '.ved') // 设置目录
const codeblog_path = os.join_path(home_dir, 'code', 'blog') // 代码博客路径
const syntax_dir = os.join_path(settings_dir, 'syntax') // 语法目录
const session_path = os.join_path(settings_dir, 'session') // 会话路径
const workspaces_path = os.join_path(settings_dir, 'workspaces') // 工作区路径
const timer_path = os.join_path(settings_dir, 'timer') // 计时器路径
const tasks_path = os.join_path(settings_dir, 'tasks') // 任务路径
const config_path = os.join_path(settings_dir, 'conf.toml') // TOML 配置文件路径
const config_path2 = os.join_path(settings_dir, 'config.json') // JSON 配置文件路径
const file_y_pos_path = os.join_path(settings_dir, 'file_y_pos') // 文件位置映射路径
const max_nr_workspaces = 10 // 最大工作区数量

// CtrlPResult 表示在 Ctrl+P 搜索中找到的文件
struct CtrlPResult {
	file_path      string // 工作区内的相对路径
	workspace_path string // 工作区路径
	display_name   string // 用于显示的预格式化名称
}

// Ved 是主应用程序结构体，包含整个编辑器的状态
@[heap]
struct Ved {
mut:
	win_width          int    // 窗口宽度
	win_height         int    // 窗口高度
	nr_splits          int    // 分屏数量
	page_height        int    // 页面高度
	views              []View // 视图列表
	cur_split          int    // 当前分屏索引
	view               &View = unsafe { nil } // 当前视图指针
	mode               EditorMode    // 编辑器模式
	just_switched      bool          // 用于按键事件，避免重复按键
	just_switched_from string        // 切换时记录触发字符，仅吞掉该字符以避免误吞正常输入
	prev_key           gg.KeyCode    // 上一个按键
	prev_key_str       string        // 用于 `ci(` 等，没有 `(` 在 gg.KeyCode 中
	prev_cmd           string        // 上一个命令
	prev_insert        string        // 用于 `.` （重新输入刚刚通过 cw 等输入的文本）
	all_git_files      []string      // 当前工作区的所有 Git 文件
	ctrlp_results      []CtrlPResult // 跨工作区的 Ctrl+P 过滤结果
	ctrlj_results      []string      // Ctrl+J 过滤结果 (打开的文件)
	top_tasks          []string      // 顶部任务
	gg                 &gg.Context = unsafe { nil } // GG 上下文指针
	query              string    // 查询字符串
	search_query       string    // 搜索查询
	query_type         QueryType // 查询类型
	workspace          string    // 当前工作区的完整路径（在顶部右侧渲染其简短版本）
	marked_text        string    // 中间 IME 文本
	workspace_idx      int       // 工作区索引
	workspaces         []string  // 工作区列表
	ylines             []string  // 用于 y, yy
	git_diff_plus      string    // 顶部右侧的简短 Git diff 统计
	git_diff_minus     string
	syntaxes           []Syntax       // 语法列表
	current_syntax_idx int            // 当前语法索引
	chunks             []Chunk        // 在高亮期间临时使用
	is_building        bool           // 是否正在构建
	is_test            bool           // 是否处于测试模式（环境变量 VED_TEST=1）
	timer              Timer          // 计时器
	task_start_unix    i64            // 任务开始时间戳
	cur_task           string         // 当前任务
	words              []string       // 单词列表
	file_y_pos         map[string]int // 为每个文件保存当前行位置
	refresh            bool = true // 刷新标志
	char_width         int      // 字符宽度
	gg_lines           []string // GG 行
	gg_pos             int      // GG 位置
	cfg                Config   // 配置
	cb                 &clipboard.Clipboard = unsafe { nil } // 剪贴板指针
	open_paths         [][]string                     // 所有打开的文件（每个工作区的标签页）：open_paths[workspace_idx] == ['a.txt', 'b.v']
	prev_y             int                            // 用于跳转回（''）
	now                time.Time                      // 缓存的 time.now() 值，避免每帧调用
	search_history     []string                       // 搜索历史
	search_idx         int                            // 搜索索引
	search_dir         string                         // 用于 cmd+/ 在当前文件所在目录中搜索
	search_dir_idx     int                            // 用于循环搜索目录文件
	error_line         string                         // 显示在底部
	autocomplete_info  AutocompleteInfo               // 自动补全信息
	autocomplete_cache map[string][]AutocompleteField // 自动补全缓存
	debug_info         string                         // 调试信息
	debugger           Debugger                       // 调试器
	cur_fn_name        string                         // 始终显示在顶部栏的当前函数名
	grep_file_exts     map[string][]string            // m['workspace_path'] == ['v', 'go']
	workspace_files    map[string][]string            // 缓存每个工作区的文件列表
	mouse_is_down      bool
	is_ctrl_pressed    bool // 用于跟踪 Control 键状态
	is_super_pressed   bool // 用于跟踪 Command (Mac) / Win (Windows) 键状态
	is_shift_pressed   bool // 用于跟踪 Shift 键状态
	// debugger_output      DebuggerOutput
	tree Tree // 用于在左侧渲染文件树
}

// Workspace 保存从工作区/路径/.ved json 文件加载的配置
struct Workspace {
	grep_file_extensions []string // Grep 文件扩展名
	// path string
}

// EditorMode 定义编辑器可以处于的不同模式，类似于 Vim
enum EditorMode {
	normal       = 0 // 正常模式
	insert       = 1 // 插入模式
	query        = 2 // 查询模式
	visual       = 3 // 可视模式
	timer        = 4 // 计时器模式
	autocomplete = 5 // 自动补全模式
	debugger     = 6 // 调试器模式
	visual_block = 7 // 块可视模式
}

// ViSize 表示视图或窗口的尺寸（宽度和高度）
struct ViSize {
	width  int // 宽度
	height int // 高度
}

const help_text = '
Usage: ved [options] [files]

Options:
  -h, --help              Display this information.
  -window <window-name>   Launch in a window.
  -dark                   Launch in dark mode.
  -two_splits
' // 帮助文本

fn get_font_path() string {
	fonts := ['AlibabaPuHuiTi-2-55-Regular.ttf', 'RobotoMono-Regular.ttf']
	for font in fonts {
		// 1. Try resource path (for .app bundle)
		mut path := os.resource_abs_path(font)
		if path != '' && os.exists(path) {
			return path
		}
		// 2. Try next to executable
		path = os.join_path(exe_dir, font)
		if os.exists(path) {
			return path
		}
		// 3. Try in ~/.ved/
		path = os.join_path(os.home_dir(), '.ved', font)
		if os.exists(path) {
			return path
		}
		// 4. Try current directory
		path = font
		if os.exists(path) {
			return path
		}
	}
	return ''
}

const fpath = get_font_path() // 字体路径
const args = os.args.clone() // 命令行参数
const is_window = '-window' in args // 是否为窗口模式

// 获取屏幕尺寸
fn get_screen_size() (int, int) {
	mut size := gg.screen_size() // 获取屏幕大小
	if os.getenv('VED_TEST') == '' {
		println('AAA SIZE=${size}')
	}
	if size.width == 0 || size.height == 0 { // 如果获取失败，使用默认大小
		size = $if small_window ? { gg.Size{770, 480} } $else { gg.Size{2560, 1440} }
	}
	// 修复 macbook notch 问题
	$if macos {
		if size.height % 20 != 0 {
			// size.height -= size.height % 20 + ved.cfg.line_height
			size.height -= 32 // ved.cfg.line_height
		}
	}
	if os.getenv('VED_TEST') == '' {
		println('size=${size}')
	}
	return size.width, size.height // 返回宽度和高度
}

// 主函数
@[console]
fn main() {
	if '-h' in args || '--help' in args { // 如果有帮助选项，打印帮助并退出
		println(help_text)
		return
	}
	if fpath == '' {
		eprintln('Error: font file not found.')
		eprintln('Please ensure "AlibabaPuHuiTi-2-55-Regular.ttf" or "RobotoMono-Regular.ttf" is in the same directory as the executable, in ~/.ved/, or in the current directory.')
		return
	}
	if !os.is_dir(settings_dir) { // 如果设置目录不存在，创建它
		os.mkdir(settings_dir) or { panic(err) }
	}
	width, height := get_screen_size() // 获取屏幕尺寸
	mut ved := &Ved{ // 创建 Ved 实例
		win_width:  width
		win_height: height
		// nr_splits: nr_splits
		// nr_splits: nr_splits
		cur_split:       0
		mode:            .normal
		is_test:         os.getenv('VED_TEST') == '1'
		cb:              clipboard.new() // 新建剪贴板
		open_paths:      [][]string{len: max_nr_workspaces} // 初始化打开路径
		workspace_files: map[string][]string{}
		file_y_pos:      map[string]int{}
		grep_file_exts:  map[string][]string{}
	}
	$if macos {
		uiold.reg_ved_instance(ved) // 注册 Ved 实例
	}
	ved.handle_segfault() // 处理段错误

	// ved.cfg.set_settings(config_path)
	if !ved.is_test {
		println('CONFIG')
		println(ved.cfg)
	}
	ved.load_config2() // 加载配置
	ved.load_file_y_pos() // 加载文件位置历史

	ved.nr_splits = ved.get_nr_splits_from_screen_size(width, height) // 根据屏幕尺寸获取分屏数量
	ved.calc_nr_splits_from_text_size() // 根据文本大小计算分屏数量
	if !ved.is_test {
		println('splits per w = ${ved.nr_splits}')
		println('height=${height}')
	}

	ved.load_syntaxes() // 加载语法

	ved.gg = gg.new_context( // 创建 GG 上下文
		width:         width
		height:        height     // borderless_window: !is_window
		fullscreen:    !is_window // 全屏模式
		window_title:  'Ved'
		create_window: true
		user_data:     ved
		scale:         2
		bg_color:      ved.cfg.bgcolor // 背景颜色
		frame_fn:      frame           // 帧函数
		on_event:      ved.on_event    // 事件处理
		keydown_fn:    on_key_down     // 按键按下函数
		keyup_fn:      on_key_up       // 按键释放函数
		char_fn:       on_char         // 字符输入函数
		font_path:     fpath           // 字体路径
		ui_mode:       true
	)
	ved.timer = new_timer(mut ved.gg) // 新建计时器
	ved.load_all_tasks() // 加载所有任务
	// TODO linux and windows
	// C.AXUIElementCreateApplication(234)
	// uiold.reg_key_ved()

	// 打开工作区或文件
	$if macos {
		if os.getenv('VED_TEST') == '' {
			spawn fn () { // 异步执行
				time.sleep(1 * time.second) // 等待 1 秒
				uiold.setup_mac_app() // 设置 mac 应用
				uiold.reg_ved_insert_cb(ved_insert_text) // 注册插入回调
				uiold.reg_ved_marked_cb(ved_marked_text) // 注册标记回调
			}()
		}
	}
	mut cur_dir := os.getwd() // 获取当前工作目录
	if cur_dir.ends_with('/ved.app/Contents/Resources') { // 如果在 app 包内，调整路径
		cur_dir = cur_dir.replace('/ved.app/Contents/Resources', '')
	}
	mut first_launch := false // 是否首次启动
	mut paths := []string{}
	for i, arg in args {
		if i == 0 {
			continue
		}
		if arg.starts_with('-') {
			continue
		}
		paths << arg
	}
	if paths.len == 0 {
		// 无参数启动，加载上次保存的工作区
		if workspaces := os.read_lines(workspaces_path) {
			for workspace in workspaces {
				ved.add_workspace(workspace)
			}
		} else {
			first_launch = true
			ved.add_workspace('.')
		}
		ved.open_workspace(0)
	}
	// 打开单个文件
	else if paths.len == 1 && os.is_file(paths[0]) {
		path := paths[0] // 获取文件路径
		if !os.exists(path) { // 如果文件不存在
			if ved.is_test {
				println('file "${path}" does not exist')
			}
			exit(1)
		}
		if ved.is_test {
			println('PATH="${path}" cur_dir="${cur_dir}"')
		}
		if !os.is_dir(path) && !path.starts_with('-') { // 如果是文件
			mut workspace := os.dir(path) // 获取目录
			ved.add_workspace(workspace) // 添加工作区
			ved.open_workspace(0) // 打开工作区
			ved.view.open_file(path, 0) // 打开文件
		}
	}
	// 打开多个工作区
	else {
		if ved.is_test {
			println('open multiple workspaces')
		}
		for arg in paths {
			if ved.is_test {
				println(arg)
			}
			// 相对路径
			if !arg.starts_with('/') {
				ved.add_workspace(cur_dir + '/' + arg) // 添加相对路径工作区
			} else {
				// 绝对路径
				ved.add_workspace(arg) // 添加绝对路径工作区
			}
		}
		if ved.workspaces.len == 0 { // 如果没有工作区
			first_launch = true
			ved.add_workspace(cur_dir) // 添加当前目录
		}
		ved.open_workspace(0) // 打开第一个工作区
	}
	ved.grep_file_exts = read_grep_file_exts(ved.workspaces) // 读取 grep 文件扩展名
	ved.load_session() // 加载会话
	ved.load_timer() // 加载计时器
	ved.init_tree() // 初始化树
	if ved.is_test {
		println('first_launch=${first_launch}')
	}
	if ved.workspaces.len == 1 && first_launch && !os.exists(session_path) { // 如果是首次启动
		ved.view.open_file(os.join_path(exe_dir, 'welcome.txt'), 0) // 打开欢迎文件
	}
	spawn ved.loop() // 启动循环
	ved.refresh = true // 设置刷新
	ved.gg.run() // 运行 GG
}

// 计算并返回单个编辑器分屏的宽度
fn (ved &Ved) split_width() int {
	mut split_width := ved.win_width / ved.nr_splits // + 60
	if split_width < 300 { // 如果宽度小于 300
		split_width = ved.win_width // 使用窗口宽度
	}
	return split_width
}

// 主绘制函数，由 gg 库在每一帧调用
fn frame(mut ved Ved) {
	// if !ved.refresh {
	// return
	// }
	// println('frame() ${time.now()}')
	ved.gg.begin() // 开始绘制
	ved.draw() // 绘制编辑器
	if ved.mode == .timer { // 如果是计时器模式
		ved.timer.draw() // 绘制计时器
	}
	ved.gg.end() // 结束绘制
	ved.refresh = false // 重置刷新标志
}

/*
fn (ved &Ved) is_in_blog() bool {
	return ved.view.path.contains('/blog/') && ved.view.path.contains('20')
}
*/

// 使用查询输入的消息提交当前工作区的更改
fn (ved &Ved) git_commit() {
	text := ved.query // 获取查询文本
	dir := ved.workspace // 获取工作区目录
	os.system('git -C ${dir} commit -am "${text}"') // 执行 git commit
	// os.system('gitter $dir')
}

// 提供基本的单词补全，通过在当前缓冲区中查找以光标下单词开头的下一个单词
fn (mut ved Ved) ctrl_n() {
	line := ved.view.line() // 获取当前行
	mut i := ved.view.x - 1 // 从光标位置开始
	end := i
	for i > 0 && is_alpha_underscore(int(line[i])) { // 向左查找单词边界
		i--
	}
	if !is_alpha_underscore(int(line[i])) {
		i++
	}
	mut word := line[i..end + 1] // 提取单词
	word = word.trim_space()
	// 如果少于 3 个字符，不进行补全
	if word.len < 3 {
		return
	}
	for map_word in ved.words { // 在单词列表中查找
		// 如果有单词以我们的子单词开头，添加其余部分
		if map_word.starts_with(word) {
			ved.view.insert_text(map_word[word.len..]) // 插入补全文本
			ved.just_switched = true
			return
		}
	}
}

// 查找并返回当前光标下的完整单词
fn (ved &Ved) word_under_cursor() string {
	line := ved.view.line() // 获取当前行
	// 首先向左查找
	mut start := ved.view.x
	if start > 0 && line.len > 0 && !is_alpha_underscore(int(line[start - 1])) {
		return ''
	}
	for start > 0 && is_alpha_underscore(int(line[start])) {
		start--
	}
	// 现在向右查找
	mut end := ved.view.x
	for end < line.len && is_alpha_underscore(int(line[end])) {
		end++
	}
	if start + 1 >= line.len || start >= end {
		return ''
	}
	// println("word under cursor line='$line' start=$start end=$end")
	// print_backtrace()
	mut word := line[start + 1..end] // 提取单词
	word = word.trim_space()
	return word
}

// 查找并返回从单词开始到光标位置的单词。用于自动补全触发
fn (ved &Ved) word_under_cursor_no_right() string {
	line := ved.view.line() // 获取当前行
	mut start := ved.view.x - 1
	// println('\n\n1line="${line}" linelen=${line.len} start=${start} s="${line[start..]}"')
	// println("C='${line[start]}'")
	for start > 0 && is_alpha_underscore(int(line[start])) { // 向左查找
		// println('minus')
		start--
	}
	// println('new start=${start}')
	mut word := line[start + 1..line.len] // 提取单词
	word = word.trim_space()
	return word
}

// 实现 Vim 中的 '*' 键功能：搜索光标下的单词
fn (mut ved Ved) star() {
	ved.search_query = ved.word_under_cursor() // 设置搜索查询
	ved.search(.forward) // 向前搜索
}

// 在 { 和 } 等之间切换
// 实现 Vim 中的 '%' 键功能：跳转到匹配的括号、大括号或圆括号
fn (mut ved Ved) pct() {
	mut line := ved.view.line() // 获取当前行
	if ved.view.x >= line.len { // 如果光标超出行长度
		return
	}
	c := line[ved.view.x] // 获取当前字符
	if c !in [`{`, `}`, `[`, `]`, `(`, `)`] { // 如果不是括号
		return
	}
	opposite_c := match c {
		// 获取匹配的字符
		`{` { `}` }
		`}` { `{` }
		`[` { `]` }
		`]` { `[` }
		`(` { `)` }
		`)` { `(` }
		else { ` ` }
	}
	going_up := c in [`}`, `]`, `)`] // 是否向上查找
	mut x := 0
	mut line_nr := ved.view.y // 当前行号
	mut stack := 0
	// for line_nr >= 1 {
	for {
		if going_up { // 如果向上查找
			line_nr-- // 行号减一
			if line_nr < 0 { // 如果行号小于 0
				break // 退出
			}
		} else { // 否则向下查找
			line_nr++ // 行号加一
			if line_nr >= ved.view.lines.len { // 如果行号超出范围
				break // 退出
			}
		}

		line = ved.view.lines[line_nr] // 获取新行
		// for x >= 1 {
		if going_up { // 如果向上
			x = line.len // 从行尾开始
		} else { // 否则
			x = -1 // 从行首开始
		}
		// TODO 处理字符串和注释中的 {}
		for {
			if going_up { // 向上查找
				x-- // x 减一
				if x < 0 { // 如果 x 小于 0
					break // 退出
				}
			} else { // 向下查找
				x++ // x 加一
				if x >= line.len { // 如果 x 超出行长度
					break // 退出
				}
			}
			if line[x] == c { // 如果找到匹配字符
				stack++ // 栈加一
			} else if line[x] == opposite_c { // 如果找到相反字符
				// println('GOT $oppsoite_c stack=${stack} line_nr=${line_nr} x=${x}')
				if stack == 0 { // 如果栈为空
					// 如果需要移动到的字符在同一页上，只更新 view.y
					// 否则移动到该行并 zz（TODO 也许移到单独的方法）
					if line_nr >= ved.view.from && line_nr <= ved.view.from + ved.page_height { // 如果在当前页
						ved.view.y = line_nr // 设置行
					} else { // 否则
						ved.move_to_line(line_nr) // 移动到行
						ved.view.zz() // 居中
					}
					// 也设置列
					ved.view.x = x // 设置列
					return
				} else {
					stack-- // 栈减一
				}
			}
		}
	}
}

// 更新活动视图指针（ved.view）以指向当前分屏
fn (mut ved Ved) update_view() {
	$if debug {
		println('update view len=${ved.views.len}')
	}
	unsafe {
		ved.view = &ved.views[ved.cur_split] // 设置当前视图
	}
}

// set_insert 切换到插入模式并聚焦原生输入
fn (mut ved Ved) set_insert() {
	ved.mode = .insert // 设置模式为插入
	ved.prev_insert = '' // 清空上一个插入
	ved.just_switched = true // 设置切换标志
	$if macos || windows {
		uiold.focus_native_input(true) // 聚焦原生输入
	}
}

// 从可视模式切换回正常模式并清除选择
fn (mut ved Ved) exit_visual() {
	println('exit visual')
	ved.mode = .normal // 设置模式为正常
	mut view := ved.view
	view.vstart = -1 // 重置选择开始
	view.vend = -1 // 重置选择结束
	$if macos || windows {
		uiold.focus_native_input(false) // 取消聚焦原生输入
	}
}

// 实现 Vim 中的 '.' 键功能：重复上一个更改命令
fn (mut ved Ved) dot() {
	prev_cmd := ved.prev_cmd // 获取上一个命令
	match prev_cmd {
		'dd' {
			ved.view.dd() // 删除行
		}
		'dw' {
			ved.view.dw(true) // 删除单词
		}
		'cw' {
			ved.view.dw(false) // 更改单词
			// println('dot cw prev_insert=$ved.prev_insert')
			ved.view.insert_text(ved.prev_insert) // 插入文本
			ved.prev_cmd = 'cw' // 设置上一个命令
		}
		'de' {
			ved.view.de() // 删除到单词结束
		}
		'J' {
			ved.view.join() // 连接行
		}
		'I' {
			ved.view.shift_i() // 插入到行首
			ved.view.insert_text(ved.prev_insert) // 插入文本
		}
		'A' {
			ved.view.shift_a() // 插入到行尾
			ved.view.insert_text(ved.prev_insert) // 插入文本
		}
		'r' {
			ved.view.r(ved.prev_insert) // 替换字符
		}
		else {}
	}
}

// 切换焦点到下一个分屏
fn (mut ved Ved) next_split() {
	from, to := ved.get_splits_from_to()
	ved.cur_split++ // 当前分屏加一
	if ved.cur_split >= to { // 如果超出当前工作区分屏范围
		ved.cur_split = from // 循环到第一个
	}
	ved.update_cur_fn_name() // 更新当前函数名
	ved.update_view() // 更新视图
	ved.just_switched = true
	ved.refresh = true // 强制刷新以更新 IME 位置
}

// 切换焦点到上一个分屏
fn (mut ved Ved) prev_split() {
	from, to := ved.get_splits_from_to()
	ved.cur_split-- // 当前分屏减一
	if ved.cur_split < from { // 如果低于当前工作区起始分屏
		ved.cur_split = to - 1 // 循环到最后一个
	}
	ved.update_cur_fn_name() // 更新当前函数名
	ved.update_view() // 更新视图
	ved.just_switched = true
	ved.refresh = true // 强制刷新以更新 IME 位置
}

// 切换到给定索引的工作区
fn (mut ved Ved) open_workspace(idx int) {
	//$if debug {
	println('open workspace(${idx})')
	//}
	if idx >= ved.workspaces.len { // 如果索引超出范围
		ved.open_workspace(0) // 打开第一个
		return
	}
	if idx < 0 { // 如果索引小于 0
		ved.open_workspace(ved.workspaces.len - 1) // 打开最后一个
		return
	}
	diff := idx - ved.workspace_idx // 计算差异
	ved.workspace_idx = idx // 设置工作区索引
	ved.workspace = ved.workspaces[idx] // 设置工作区
	// 更新当前分屏索引。如果我们在空间 0 分屏 1 并转到空间 1，分屏更新为 4 (1 + 3 * (1-0))
	ved.cur_split += diff * ved.nr_splits // 更新分屏索引

	// 为新工作区加载 git 文件
	ved.load_git_tree() // 加载 git 树

	for i, view in ved.views { // 遍历视图
		// 也许文件没有正确加载（可能在 ved 启动时发生）
		// 尝试重新打开
		if view.lines.len < 2 && view.path != '' { // 如果行数少且有路径
			ved.views[i].open_file(view.path, ved.view.y) // 重新打开文件
		}
	}
	ved.update_view() // 更新视图
	// ved.get_git_diff()
}

// 添加新工作区到编辑器并为它创建必要的视图
fn (mut ved Ved) add_workspace(path string) {
	//$if debug {
	println('add_workspace("${path}")')
	//}
	// if ! os.exists(path) {
	// ui.alert('"$path" doesnt exist')
	// }
	// TODO autofree bug. not freed
	mut workspace := if path == '.' { os.getwd() } else { path } // 获取工作区路径
	if workspace.ends_with('/.') { // 如果以 /. 结尾
		workspace = workspace[..workspace.len - 2] // 移除
	}
	if ved.workspaces.len >= max_nr_workspaces { // 如果超出最大工作区数量
		// ui.alert('workspace limit')
		return
	}
	ved.workspaces << workspace // 添加工作区
	for i := 0; i < ved.nr_splits; i++ { // 为每个分屏创建视图
		ved.views << ved.new_view() // 添加新视图
	}
}

// 返回工作区路径的缩短版本用于显示
fn short_space(workspace string) string {
	pos := workspace.last_index(os.path_separator) or { return workspace } // 查找最后一个路径分隔符
	return workspace[pos + 1..].limit(10) // 返回最后部分，限制长度为 10
}

// 将视图移动到特定行号
fn (mut ved Ved) move_to_line(n int) {
	ved.prev_y = ved.view.y // 保存上一个 y 位置
	ved.view.from = n // 设置视图起始行
	ved.view.set_y(n) // 设置 y 位置
}

// 保存会话，包括打开的文件、光标位置和工作区列表到磁盘
fn (ved &Ved) save_session() {
	println('saving session...') // 打印保存信息
	mut f := os.create(session_path) or { panic('fail') } // 创建会话文件
	for _, view in ved.views { // 遍历视图
		// println('saving view #${i} ${view.path}')
		// if view.path == '' {
		// continue
		// }
		if view.path == 'out' { // 如果是 out 文件，跳过
			continue
		}
		f.writeln('${view.path}:${view.y}') or { panic(err) } // 写入路径和行号
	}
	f.close() // 关闭文件
	mut f_workspace := os.create(workspaces_path) or { panic(err) } // 创建工作区文件
	for workspace in ved.workspaces { // 遍历工作区
		f_workspace.writeln(workspace) or { panic(err) } // 写入工作区
	}
	f_workspace.close() // 关闭文件
	ved.save_file_y_pos()
}

// 保存每个文件的光标位置
fn (ved &Ved) save_file_y_pos() {
	mut f := os.create(file_y_pos_path) or { return }
	for path, y in ved.file_y_pos {
		if path == '' {
			continue
		}
		f.writeln('${path}:${y}') or { break }
	}
	f.close()
}

// 加载每个文件的光标位置
fn (mut ved Ved) load_file_y_pos() {
	if !os.exists(file_y_pos_path) {
		return
	}
	lines := os.read_lines(file_y_pos_path) or { return }
	for line in lines {
		if !line.contains(':') {
			continue
		}
		parts := line.split(':')
		if parts.len != 2 {
			continue
		}
		path := parts[0]
		y := parts[1].int()
		ved.file_y_pos[path] = y
	}
}

// 辅助函数，将字符串转换为 i64
fn toi(s string) i64 {
	return s.i64() // 转换为整数
}

// 保存当前任务和计时器状态到磁盘
fn (ved &Ved) save_timer() {
	mut f := os.create(timer_path) or { return } // 创建计时器文件
	f.writeln('task=${ved.cur_task}') or { panic(err) } // 写入当前任务
	f.writeln('task_start=${ved.task_start_unix}') or { panic(err) } // 写入任务开始时间
	// f.writeln('timer_typ=$ved.timer.cur_type') or { panic(err) }
	/*
	if ved.timer.started {
		f.writeln('timer_start=$ved.timer.start_unix') or { panic(err) }
	}
	else {
		f.writeln('timer_start=0') or { panic(err) }
	}
	*/
	f.close() // 关闭文件
}

// 从磁盘加载任务和计时器状态
fn (mut ved Ved) load_timer() {
	// task=do work
	// task_start=1223212221
	// timer_typ=7
	// timer_start=12321321
	lines := os.read_lines(timer_path) or { return } // 读取计时器文件
	if lines.len == 0 { // 如果没有行
		return
	}
	println(lines) // 打印行
	mut vals := []string{} // 值列表
	for line in lines { // 遍历行
		words := line.split('=') // 分割
		if words.len != 2 { // 如果不是键值对
			vals << '' // 添加空值
			// exit('bad timer format')
		} else {
			vals << words[1] // 添加值
		}
	}
	// mut task := lines[0]
	// println('vals=')
	// println(vals)
	ved.cur_task = vals[0] // 设置当前任务
	ved.task_start_unix = toi(vals[1]) // 设置任务开始时间
	// ved.timer.cur_type = toi(vals[2])
	// ved.timer.start_unix = toi(vals[3])
	// ved.timer.started = ved.timer.start_unix != 0
}

// 加载最后保存的会话，包括工作区和打开的文件
fn (mut ved Ved) load_session() {
	println('load session "${session_path}"') // 打印加载信息
	paths := os.read_lines(session_path) or { return } // 读取会话文件
	println(paths) // 打印路径
	ved.load_views(paths) // 加载视图
}

// 根据保存的会话数据打开文件并设置光标位置
fn (mut ved Ved) load_views(paths []string) {
	for i := 0; i < paths.len && i < ved.views.len; i++ { // 遍历路径
		// println('loading path')
		// println(paths[i])
		// mut view := &ved.views[i]
		mut path := paths[i] // 获取路径
		mut line_nr := 0 // 行号
		if path == '' || path.contains('=') { // 如果路径为空或包含 =
			continue // 跳过
		}
		if path.contains(':') { // 如果包含行号
			// myfile.v:23
			// 可以包含上一会话的行号，解析并转到它们
			vals := path.split(':') // 分割
			path = vals[0] // 路径
			line_nr = vals[1].int() // 行号
		}
		// view.open_file(path)
		ved.views[i].open_file(path, line_nr) // 打开文件
	}
}

// 获取当前工作区的简短 git diff 状态
fn (ved &Ved) get_git_diff() {
	/*
	return
	dir := ved.workspace
	mut s := os.system('git -C $dir diff --shortstat')
	vals := s.split(',')
	if vals.len < 2 {
		return
	}
	println(vals.len)
	// vals[1] == "2 insertions(+)"
	mut plus := vals[1]
	plus = plus.find_between(' ', 'insertion')
	plus = plus.trim_space()
	ved.git_diff_plus = '$plus+'
	if vals.len < 3 {
		return
	}
	mut minus := vals[2]
	minus = minus.find_between(' ', 'deletion')
	minus = minus.trim_space()
	ved.git_diff_minus = '$minus-'
	*/
}

// 获取完整的 git diff，在新分屏中显示，如果没有 diff 则打开 git log
fn (ved &Ved) get_git_diff_full() string {
	dir := ved.workspace // 获取工作区目录
	os.system('git -C ${dir} diff > ${dir}/out') // 执行 git diff 并输出到 out
	mut last_view := ved.get_last_view() // 获取最后一个视图
	last_view.open_file('${dir}/out', 0) // 打开 out 文件
	// 没有提交（diff = 0），显示 git log
	if last_view.lines.len < 2 { // 如果行数少
		// os.system('echo "no diff\n" > $dir/out')
		os.system('git -C ${dir} log -n 40 --pretty=format:"%ad %s" ' + // 执行 git log
		 '--simplify-merges --date=format:"%Y-%m-%d %H:%M  "> ${dir}/out')
		last_view.open_file('${dir}/out', 0) // 打开 out 文件
	}
	last_view.gg() // 执行 gg
	return 's'
}

// 创建并/或打开当前日期的新博客文章文件
fn (mut ved Ved) open_blog() {
	now := time.now() // 获取当前时间
	path := os.join_path(codeblog_path, '${now.year}', '${now.month:02d}', '${now.day:02d}') // 构建路径
	parent_dir := os.dir(path) // 获取父目录
	parent_dir2 := os.dir(parent_dir) // 获取祖父目录
	if !os.exists(parent_dir2) { // 如果不存在
		os.mkdir(parent_dir2) or { panic(err) } // 创建目录
	}
	if !os.exists(parent_dir) { // 如果不存在
		os.mkdir(parent_dir) or { panic(err) } // 创建目录
	}
	if !os.exists(path) { // 如果文件不存在
		os.system('touch ${path}') // 创建文件
	}
	mut last_view := ved.get_last_view() // 获取最后一个视图
	last_view.open_file(path, 0) // 打开文件
	last_view.gg() // 执行 gg
	// last_view.shift_g()
	// 转到打开的博客（TODO 必须有更简单的方法）
	for i := 0; i < 5; i++ { // 循环切换分屏
		if ved.view.path == path { // 如果路径匹配
			break // 退出
		}
		ved.next_split() // 下一个分屏
	}
}

// 返回当前工作区内最后一个视图的引用
fn (ved &Ved) get_last_view() &View {
	pos := (ved.workspace_idx + 1) * ved.nr_splits - 1 // 计算位置
	eprintln('> ${@METHOD} pos: ${pos}') // 打印调试信息
	unsafe {
		return &ved.views[pos] // 返回视图引用
	}
}

// 返回当前工作区内最后一个视图的索引
fn (ved &Ved) last_view_idx() int {
	return (ved.workspace_idx + 1) * ved.nr_splits - 1 // 计算索引
}

// 遍历所有打开的视图并保存任何已修改的文件
fn (mut ved Ved) save_changed_files() {
	for i, view in ved.views { // 遍历视图
		if view.changed { // 如果已更改
			ved.views[i].save_file() // 保存文件
		}
	}
}

// 查找当前工作区的构建脚本位置
fn (mut ved Ved) get_build_file_location() ?string {
	dir := ved.workspace // 获取工作区目录
	mut build_file := '${dir}/build' // 构建文件路径
	if !os.exists(build_file) { // 如果不存在
		build_file = '${dir}/.ved/build' // 尝试 .ved 目录
		if !os.exists(build_file) { // 如果不存在
			return none // 返回 none
		}
	}
	return build_file // 返回路径
}

// 解析编译器错误消息，必要时打开相应文件，并跳转到错误位置
fn (mut ved Ved) go_to_error(line string, error_details string) {
	ved.error_line = line.after('error: ') // 设置错误行
	ved.error_line += '    ' + error_details // 添加详情
	// panic: volt/twitch.v:88
	println('go to ERROR line="${line}" error_details=${error_details}') // 打印调试信息
	// line = line.replace('panic: ', '')
	vals := line.split(':') // 分割行
	println('vals=${vals}') // 打印值
	if vals.len < 4 { // 如果值不够
		return
	}
	mut filename := vals[0] // 获取文件名
	if filename.starts_with('./') { // 如果以 ./ 开头
		filename = filename[2..] // 移除
	}
	ext := os.file_ext(filename) // 获取扩展名
	println('ext="${ext}"') // 打印扩展名
	pos := line.index(ext + ':') or { // 查找位置
		println('no 2 :')
		return
	}
	path := line[..pos] // 获取路径
	line_nr := vals[1].int() // 获取行号
	col := vals[2].int() // 获取列号
	println('path=${path} filename=${filename} linenr=${line_nr} col=${col}') // 打印信息
	// 在当前工作区的所有视图中搜索包含错误的视图
	start_i := ved.workspace_idx * ved.nr_splits // 开始索引
	end_i := (ved.workspace_idx + 1) * ved.nr_splits // 结束索引
	for i := start_i; i < end_i && i < ved.views.len; i++ { // 遍历视图
		mut view := unsafe { &ved.views[i] } // 获取视图
		if !view.path.contains(os.path_separator + filename) && view.path != filename { // 如果路径不匹配
			continue // 跳过
		}
		view.error_y = line_nr - 1 // 设置错误行
		println('i=${i} view.path=${view.path} error_y=${view.error_y} ') // 打印信息
		view.move_to_line(view.error_y) // 移动到行
		if col > 0 { // 如果有列号
			view.x = col - 1 // 设置列
		}
		// view.ved.main_wnd.refresh()
		// 在第一个包含错误的视图后完成
		return
	}
	println('file with error not found (not open), running git ls-files') // 文件未打开，运行 git ls-files
	// 文件现在未打开，执行
	s := os.execute('git -C ${ved.workspace} ls-files') // 执行 git 命令
	if s.exit_code == -1 { // 如果失败
		return
	}
	mut lines := s.output.split_into_lines() // 分割输出
	lines.sort_by_len() // 按长度排序
	for git_file in lines { // 遍历文件
		if git_file.contains(filename) { // 如果包含文件名
			ved.view.open_file(git_file, ved.view.error_y) // 打开文件
			ved.view.error_y = line_nr - 1 // 设置错误行
			ved.view.move_to_line(ved.view.error_y) // 移动到行
			if col > 0 { // 如果有列号
				ved.view.x = col - 1 // 设置列
			}
			return
		}
	}
}

// 编辑器主后台循环，负责定期刷新和任务
fn (mut ved Ved) loop() {
	for { // 无限循环
		ved.refresh = true // 设置刷新
		ved.now = time.now() // 更新时间
		ved.gg.refresh_ui() // 刷新 UI
		// ved.timer.tick(ved)
		time.sleep(5 * time.second) // 睡眠 5 秒
		if ved.timer.pom_is_started && ved.now.local_unix() - ved.timer.pom_start > 25 * 60 { // 如果番茄钟启动且超过 25 分钟
			ved.timer.pom_is_started = false // 停止
			lock_screen() // 锁定屏幕
		}
	}
}

// 自定义键绑定，运行当前测试文件或构建应用程序
fn (mut ved Ved) key_u() {
	// 运行单个测试文件
	if ved.view.path.ends_with('_test.v') { // 如果是测试文件
		ved.run_file() // 运行文件
	} else {
		ved.refresh = true // 设置刷新
		spawn ved.build_app1() // 异步构建应用
	}
}

// 分段错误信号处理程序，尝试在退出前保存工作
fn segfault_sigaction(signal int, si voidptr, arg voidptr) {
	println('crash!') // 打印崩溃信息
	/*
	mut ved := &Ved{!}
	//# ved=g_ved;
	# ved=arg;
	println(ved.cfg.line_height)
	// ved.save_session()
	// ved.save_timer()
	ved.save_changed_files()
	// #const char buf[ ] = "your message\n";
	// #write(STDOUT_FILENO, buf, strlen(buf));
	// #printf("Caught segfault at address %p\n", si->si_addr);
	// #send_error(tos("segfault"));
	// #printf("SEGFAULT %08x \n", pthread_self());
	println('forking...')
	// # execv("myvim", (char *[]){ "./myvim", 0});
	println('done forking...')
	*/
	exit(1) // 退出
}

// 设置分段错误的自定义信号处理程序
fn (ved &Ved) handle_segfault() {
	$if windows {
		return
	}
	/*
	# g_ved= ctx ;
	# struct sigaction sa;
	# int *foo = NULL;
	# memset(&sa, 0, sizeof(struct sigaction));
	# sigemptyset(&sa.sa_mask);
	# sa.sa_sigaction = segfault_sigaction;
	# sa.sa_flags   = SA_SIGINFO;
	# sigaction(SIGSEGV, &sa, 0);
	*/
}

// 计算并返回当前任务花费的分钟数
fn (ved &Ved) task_minutes() int {
	mut seconds := ved.now.local_unix() - ved.task_start_unix // 计算秒数
	if ved.task_start_unix <= 0 { // 如果未开始
		seconds = 0 // 设置为 0
	}
	return int(seconds / 60) // 返回分钟数
}

// 在当前工作区目录执行 `git pull --rebase`
fn (mut ved Ved) git_pull() {
	// Run git pull and then invalidate/refresh the workspace file cache so searches
	// pick up newly pulled files or deletions.
	os.system('git -C "${ved.workspace}" pull --rebase') // 执行 git 命令
	// Clear cached files for this workspace and reload the git tree
	if ved.workspace in ved.workspace_files {
		ved.workspace_files.delete(ved.workspace)
	}
	// Reload files for the workspace to refresh caches (safe if called from spawn)
	ved.load_git_tree()
	ved.mode = .normal // 设置模式为正常
	ved.gg.refresh_ui() // 刷新 UI
}

const text_scale = 1.2 // 文本缩放

const max_text_size = 24 // 最大文本大小
const min_text_size = 18 // 最小文本大小

// 更改编辑器的字体大小并重新计算相关 UI 指标
fn (mut ved Ved) increase_font(delta int) {
	// println('INCREASE_FONT(${delta})')
	// println('text_size=${ved.cfg.text_size}')
	// println('char_width=${ved.cfg.char_width}')
	// println('line_height=${ved.cfg.line_height}')
	ved.cfg.text_size += delta * 2 // 增加文本大小
	if ved.cfg.text_size > max_text_size { // 如果超过最大
		ved.cfg.text_size = max_text_size // 设置为最大
		return
	}
	if ved.cfg.text_size < min_text_size { // 如果低于最小
		ved.cfg.text_size = min_text_size // 设置为最小
		return
	}
	ved.cfg.char_width += delta // 增加字符宽度
	// ved.cfg.char_width = ved.cfg.text_size - 10
	ved.cfg.line_height = ved.cfg.text_size + 2 // 设置行高
	// x := ved.cfg.txt_cfg
	ved.cfg.txt_cfg = gg.TextCfg{ // 更新文本配置
		...ved.cfg.txt_cfg // 展开现有配置
		size: ved.cfg.text_size // 设置大小
	}
	ved.cfg.comment_cfg = gg.TextCfg{ // 更新注释配置
		...ved.cfg.comment_cfg
		size: ved.cfg.text_size
	}
	ved.cfg.key_cfg = gg.TextCfg{ // 更新关键字配置
		...ved.cfg.key_cfg
		size: ved.cfg.text_size
	}
	ved.cfg.line_nr_cfg = gg.TextCfg{ // 更新行号配置
		...ved.cfg.line_nr_cfg
		size: ved.cfg.text_size
	}
	ved.cfg.string_cfg = gg.TextCfg{ // 更新字符串配置
		...ved.cfg.string_cfg
		size: ved.cfg.text_size
	}
	ved.cfg.file_name_cfg = gg.TextCfg{ // 更新文件名配置
		...ved.cfg.file_name_cfg
		size: ved.cfg.text_size
	}
	// println('NEW text_size=${ved.cfg.text_size}')
	// println('NEW char_width=${ved.cfg.char_width}')
	// println('NEW line_height=${ved.cfg.line_height}\n')
	ved.calc_nr_splits_from_text_size() // 根据文本大小重新计算分屏数量
	ved.save_config2() // 保存配置
	// println('NEW  CONFIG')
	// println(ved.cfg)
}

// 根据当前字体大小调整可见分屏数量以保持可读性
fn (mut ved Ved) calc_nr_splits_from_text_size() {
	if ved.cfg.text_size > 20 && ved.nr_splits > 2 { // 如果文本大小大于 20 且分屏大于 2
		ved.nr_splits = 2 // 设置为 2
	} else if ved.cfg.text_size <= 20 { // 如果文本大小小于等于 20
		ved.nr_splits = ved.get_nr_splits_from_screen_size(ved.win_width, ved.win_height) // 根据屏幕尺寸获取
	}
}

// 从字符串中移除 ANSI 颜色转义码
fn filter_ascii_colors(s string) string {
	return s.replace_each(['[22m', '', '[35m', '', '[39m', '', '[1m', '', '[31m', '']) // 替换颜色码
}

// 根据屏幕宽度确定默认分屏数量
fn (ved &Ved) get_nr_splits_from_screen_size(width int, height int) int {
	println('screen_width=${width}') // 打印屏幕宽度
	mut nr_splits := 3 // 默认 3
	if '-two_splits' in args || width < 1800 { // 如果参数或宽度小于 1800
		nr_splits = 2 // 设置为 2
	}
	if is_window || '-laptop' in args { // 如果是窗口或笔记本参数
		nr_splits = 1 // 设置为 1
	}
	max_split_width := ved.cfg.char_width * 110 // 计算最大分屏宽度
	println('MAX=${max_split_width}') // 打印最大宽度
	if unsafe { false } { // 如果 false
		exit(1) // 退出
	}
	return nr_splits // 返回分屏数量
}

// 返回属于当前工作区的视图的起始和结束索引
fn (ved &Ved) get_splits_from_to() (int, int) {
	from := ved.workspace_idx * ved.nr_splits // 计算起始
	to := from + ved.nr_splits // 计算结束
	return from, to // 返回
}

// 查找光标当前所在的函数名并更新状态以在顶部栏显示
fn (mut ved Ved) update_cur_fn_name() {
	if !(ved.view.path.ends_with('.v') || ved.view.path.ends_with('.go')) { // 如果不是 V 或 Go 文件
		ved.cur_fn_name = '' // 清空函数名
		return
	}
	if ved.view.lines.len < 2 { // 如果行数少
		// 也许文件没有正确加载（可能在 ved 启动时发生）
		// 尝试重新打开
		return
	}
	// TODO 优化，无分配
	for i := int_min(ved.view.y - 1, ved.view.lines.len - 1); i >= 0; i-- { // 从当前行向上查找
		line := ved.view.lines[i] // 获取行
		if line == '}' { // 如果是 }
			ved.cur_fn_name = '' // 清空
			break
		}
		if line.starts_with('fn ') || line.starts_with('pub fn ') { // 如果是函数定义
			fn_pos := line.index('fn ') or { continue }
			mut start := fn_pos + 3
			mut end := line.index_after('(', start) or { -1 }
			if end == -1 {
				end = line.index_after('{', start) or { -1 }
			}
			if end == -1 {
				end = line.len
			}
			ved.cur_fn_name = line[start..end].trim_space()
			break
		}
	}
}

// 从每个工作区的 .ved 配置文件读取要在目录范围搜索中包含的文件扩展名
fn read_grep_file_exts(workspaces []string) map[string][]string {
	mut res := map[string][]string{} // 结果映射
	for w in workspaces { // 遍历工作区
		path := '${w}/.ved' // 配置文件路径
		if !os.exists(path) { // 如果不存在
			continue // 跳过
		}
		f := os.read_file(path) or { // 读取文件
			println(err)
			continue
		}
		x := json2.decode[Workspace](f) or { // 解码 JSON
			println(err)
			continue
		}
		res[w] = x.grep_file_extensions // 设置扩展名
		println('got ${x.grep_file_extensions} exts for workspace ${w}') // 打印信息
	}
	return res // 返回结果
}

// 列出给定工作区路径的所有文件，最好使用 `git ls-files`
// （类似于 load_git_tree 但针对性）
fn (mut ved Ved) get_files_for_workspace(ws_path string) []string {
	if ws_path == '' { // 如果路径为空
		return [] // 返回空
	}
	// 检查缓存
	if ws_path in ved.workspace_files {
		return ved.workspace_files[ws_path]
	}
	// 首先检查是否是 git 仓库
	mut is_git := false // 是否 git
	out_git_check := os.execute('git -C "${ws_path}" rev-parse --is-inside-work-tree') // 执行 git 命令
	if out_git_check.exit_code != -1 { // 如果成功
		is_git = out_git_check.output.trim_space() == 'true' // 设置为 true
	}

	mut files := []string{}
	if is_git { // 如果是 git
		s := os.execute('git -C ${ws_path} ls-files') // 执行 ls-files
		if s.exit_code == -1 { // 如果失败
			return []string{} // 返回空
		}
		files = s.output.split_into_lines() // 分割输出
		files.sort_by_len()
	} else {
		// 如果不是 git，我们可以列出所有文件。TODO：排除一些目录
		// files = os.walk_ext(ws_path, '')
	}
	ved.workspace_files[ws_path] = files
	return files // 返回结果
}

fn (mut ved Ved) enter_query_mode(query_type QueryType, initial_query string, trigger string) {
	ved.mode = .query
	ved.query_type = query_type
	ved.query = initial_query
	ved.just_switched = true
	ved.just_switched_from = trigger
	ved.refresh = true
}
