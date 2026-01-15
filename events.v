module main // 主模块

import os // 导入 os 模块
import gg // 导入 gg 模块
import uiold // 导入 uiold 模块

// on_event handles various GUI events like mouse clicks, scrolls, and window resizing.
// on_event 处理各种 GUI 事件，如鼠标点击、滚动和窗口调整大小。
fn (mut ved Ved) on_event(e &gg.Event) {
	// println('on_event ${ved.win_width}')
	ved.refresh = true // 设置刷新
	/*
	// TODO change win height/width only on cmd + enter (exit full screen etc)
	// TODO 仅在 cmd + enter 时更改窗口高度/宽度（退出全屏等）
	mut size := gg.screen_size() // 获取屏幕大小

	// Fix macbook notch crap
	// 修复 macbook notch 问题
	$if macos { // 如果是 macos
		if size.height % 20 != 0 { // 如果高度不是 20 的倍数
			// size.height -= size.height % 20 + ved.cfg.line_height
			size.height -= 32 // ved.cfg.line_height // 减少高度
		}
	}
	ved.win_height = size.height // 设置窗口高度
	ved.win_width = size.width // 设置窗口宽度
	*/

	if e.typ == .mouse_scroll { // 如果是鼠标滚动
		if e.scroll_y < -0.2 { // 如果向下滚动
			ved.view.j() // 向下移动
		} else if e.scroll_y > 0.2 { // 如果向上滚动
			ved.view.k() // 向上移动
		}
	}

	// FIXME: The rounding math here cause the Y coord to be unintuitive sometimes.
	// FIXME: 此处的舍入数学有时会导致 Y 坐标不直观。
	if e.typ == .mouse_down { // 如果是鼠标按下
		if ved.cfg.disable_mouse { // 如果禁用鼠标
			return // 返回
		}

		mut view := ved.view // 获取视图

		mut current_line := '' // 当前行
		if view.y > 0 && view.y < view.lines.len { // 如果 y 在范围内
			current_line = view.lines[view.y] // 设置当前行
		}
		current_line_split := current_line.split('\t') // 按制表符分割
		mut leading_tabs := 0 // 前导制表符
		for i := 0; i < current_line_split.len; i++ { // 遍历分割
			if current_line_split[i] == '' { // 如果为空
				leading_tabs++ // 增加前导制表符
			}
		}

		// Focus the pane currently under the cursor before continuing
		// 在继续之前聚焦光标下的窗格
		for i := 0; i < ved.nr_splits; i++ { // 遍历分屏
			sw := ved.split_width() // 获取分屏宽度
			starting_x := 2 * i * sw // 开始 x
			ending_x := 2 * (i + 1) * sw // 结束 x

			if e.mouse_x > starting_x && e.mouse_x < ending_x { // 如果鼠标 x 在范围内
				ved.cur_split = i // 设置当前分屏
				ved.update_view() // 更新视图
			}
		}

		clicked_y := int((e.mouse_y / ved.cfg.line_height - 1.5) / 2) + ved.view.from // 计算点击的 y
		if clicked_y >= view.lines.len { // 如果超出
			if view.lines.len == 0 { // 如果行数为 0
				view.set_y(0) // 设置 y 为 0
			} else { // 否则
				view.set_y(view.lines.len - 1) // 设置为最后一行
			}
		} else if clicked_y < 0 { // 如果小于 0
			view.set_y(1) // 设置为 1
		} else { // 否则
			view.set_y(clicked_y) // 设置 y
		}

		// Wow, that's a lot of math that is probably pretty hard to parse.
		// In the future I need to separate this into several variables,
		// and perhaps even its own function.
		// 哇，这有很多数学，可能很难解析。
		// 将来我需要将其分离到几个变量中，甚至可能是自己的函数。
		clicked_x := int(((e.mouse_x - ved.cur_split * ved.split_width() * 2 - view.padding_left) / ved.cfg.char_width) / 2 - 3 - leading_tabs * 3) // 计算点击的 x
		if view.lines.len <= 0 { // 如果行数 <= 0
			return // 返回
		}
		if clicked_x > view.lines[view.y].len { // 如果超出
			view.x = view.lines[view.y].len // 设置 x 为行长
		} else if clicked_x < 0 { // 如果小于 0
			view.x = 0 // 设置为 0
		} else { // 否则
			view.x = clicked_x // 设置 x
		}
	}
}

// key_down handles key press events and dispatches them based on the current mode.
// key_down 处理按键事件，并根据当前模式分派它们。
fn key_down(key gg.KeyCode, mod gg.Modifier, mut ved Ved) {
	super := mod == .super // 是否是 super 键
	if key == .escape { // 如果是 escape
		if ved.mode == .visual { // 如果是视觉模式
			ved.exit_visual() // 退出视觉模式
		}
		ved.mode = .normal // 设置为正常模式
		$if macos { // 如果是 macos
			uiold.focus_native_input(false) // 聚焦原生输入
		}
	}
	// Reset error line
	// 重置错误行
	ved.view.error_y = -1 // 设置 error_y
	ved.error_line = '' // 设置 error_line
	match ved.mode { // 匹配模式
		.normal { ved.key_normal(key, mod) } // 正常模式
		.visual { ved.key_visual(key, mod) } // 视觉模式
		.insert { ved.key_insert(key, mod) } // 插入模式
		.query { ved.key_query(key, super) } // 查询模式
		.timer { ved.timer.key_down(key, super) } // 计时器模式
		.autocomplete { ved.key_insert(key, mod) } // 自动完成模式
		.debugger { ved.key_normal(key, mod) } // 调试器模式
	}
	ved.gg.refresh_ui() // 刷新 UI
}

// key_normal handles key presses in normal mode.
// key_normal 处理正常模式下的按键。
fn (mut ved Ved) key_normal(key gg.KeyCode, mod gg.Modifier) {
	super := mod == .super || mod == .ctrl // 是否是 super 或 ctrl
	shift := mod == .shift // 是否是 shift
	// println('mod=')
	// println(int(mod))
	shift_and_super := int(mod) == 9 // shift 和 super
	mut view := ved.view // 获取视图
	ved.refresh = true // 设置刷新
	if ved.prev_key == .r { // 如果 prev_key 是 r
		return // 返回
	}
	if ved.prev_cmd == 'ci' { // 如果 prev_cmd 是 ci
		println('CALLING CI PREV S=${ved.prev_key_str}') // 打印
		view.ci(key) // 调用 ci
		return // 返回
	}
	match key { // 匹配 key
		.enter { // enter
			// Full screen => window
			// 全屏 => 窗口
			// Update screen size
			// 更新屏幕大小
			if super { // 如果 super
				println('full screen') // 打印全屏
				width, height := get_screen_size() // 获取屏幕大小

				// ved.nr_splits = 1
				ved.win_width = width // 设置窗口宽度
				ved.win_height = height // 设置窗口高度
				// glfw.post_empty_event()
			}
		}
		.period { // .
			if shift { // 如果 shift
				// >
				ved.view.shift_right() // 右移
			} else { // 否则
				ved.dot() // dot
			}
		}
		.comma { // ,
			if shift { // 如果 shift
				// <
				ved.view.shift_left() // 左移
			} else if super { // 如果 super
				//
				// ved.cfg.reload_config()
				// ved.update_view()
			}
		}
		.slash { // /
			ved.search_query = '' // 设置搜索查询
			ved.mode = .query // 设置模式为查询
			ved.just_switched = true // 设置 just_switched
			ved.search_dir = '' // 设置搜索目录
			if shift { // 如果 shift
				ved.query_type = .grep // 设置查询类型为 grep
			} else if super { // 如果 super
				ved.query_type = .search_in_folder // 设置为文件夹搜索
				ved.search_dir = os.dir(ved.view.path) // 设置搜索目录
			} else { // 否则
				ved.query_type = .search // 设置为搜索
			}
		}
		.f5 { // f5
			ved.run_file() // 运行文件
			// ved.cfg.char_width -= 1
			// ved.cfg.line_height -= 1
			// ved.font_size -= 1
			// ved.page_height = WIN_HEIGHT / ved.cfg.line_height - 1
			// case C.GLFW_KEY_F6:
			// ved.cfg.char_width += 1
			// ved.cfg.line_height += 1
			// ved.font_size += 1
			// ved.page_height = WIN_HEIGHT / ved.cfg.line_height - 1
			// ved.vg = gg.new_context(WIN_WIDTH, WIN_HEIGHT, ved.font_size)
		}
		.minus { // -
			if shift_and_super { // 如果 shift 和 super
				// println('FONT DECREASE')
				ved.increase_font(-1) // 减少字体
			} else if super { // 如果 super
				ved.get_git_diff_full() // 获取完整 git diff
			}
		}
		.equal { // =
			if shift { // 如果 shift
				ved.prev_key = .equal // 设置 prev_key
			} else if shift_and_super { // 如果 shift 和 super
				ved.increase_font(1) // 增加字体
				// println('FONT INCREASE')
			}
		}
		.f12 { // f12
			if shift { // 如果 shift
				ved.open_blog() // 打开博客
			}
		}
		.apostrophe { // '
			if ved.prev_key == .apostrophe { // 如果 prev_key 是 '
				ved.prev_key = gg.KeyCode.invalid // 设置无效
				ved.move_to_line(ved.prev_y) // 移动到行
				return // 返回
			}
		}
		._0 { // 0
			if super { // 如果 super
				// 触发“新建任务”：进入查询模式，类型设为任务(task)
				// 确认后将开始计时并计入当日生产力时长统计
				ved.query = '' // 设置查询
				ved.mode = .query // 设置模式
				ved.query_type = .task // 设置查询类型
				ved.just_switched = true // 设置 just_switched
			} else { // 否则
				view.zero() // zero
			}
		}
		._9 { // 9
			if super { // 如果 super
				// 触发“新建非生产力任务”：任务名前缀加 @
				// 确认后将开始计时，但在统计时会被视为休息或分心时间（显示为粉色）
				ved.query = '@' // 设置查询
				ved.mode = .query // 设置模式
				ved.query_type = .task // 设置查询类型
				ved.just_switched = true // 设置 just_switched
			}
		}
		.a { // a
			if shift { // 如果 shift
				// Vim 风格：Shift + A 跳转到行尾并进入插入模式
				ved.view.shift_a() // shift_a
				ved.prev_cmd = 'A' // 设置 prev_cmd
				ved.set_insert() // 设置插入
			} else if super { // 如果 super
				// Command + A：将光标所在行找到的第一个数字增加 1
				// 类似 Vim 中的 Ctrl + A 功能
				ved.view.super_a(1) // super_a
				ved.prev_cmd = 'a' // 设置 prev_cmd
			}
		}
		.c { // c
			if super { // 如果 super
				ved.query = '' // 设置查询
				ved.mode = .query // 设置模式
				ved.query_type = .cam // 设置查询类型
				ved.just_switched = true // 设置 just_switched
			} else if shift { // 如果 shift
				ved.prev_insert = ved.view.shift_c() // 设置 prev_insert
				ved.set_insert() // 设置插入
			}
		}
		.d { // d
			if super { // 如果 super
				ved.prev_split() // 上一个分屏
				return // 返回
			}
			if ved.prev_key == .d { // 如果 prev_key 是 d
				ved.view.dd() // dd
				return // 返回
			} else if ved.prev_key == .g { // 如果 prev_key 是 g
				ved.go_to_def() // 转到定义
			}
		}
		.e { // e
			if super { // 如果 super
				ved.next_split() // 下一个分屏
				return // 返回
			}
			if ved.prev_key == .c { // 如果 prev_key 是 c
				view.ce() // ce
			} else if ved.prev_key == .d { // 如果 prev_key 是 d
				view.de() // de
			}
		}
		.i { // i
			if shift { // 如果 shift
				ved.view.shift_i() // shift_i
				ved.set_insert() // 设置插入
				ved.prev_cmd = 'I' // 设置 prev_cmd
			} else { // 否则
				if ved.prev_key == .c { // 如果 prev_key 是 c
					ved.prev_cmd = 'ci' // 设置 prev_cmd
				} else { // 否则
					ved.set_insert() // 设置插入
				}
			}
		}
		.j { // j
			if shift { // 如果 shift
				ved.view.join() // join
			} else if super { // 如果 super
				ved.mode = .query // 设置模式
				ved.query_type = .ctrlj // 设置查询类型
				// ved.load_open_files()
				ved.query = '' // 设置查询
				ved.just_switched = true // 设置 just_switched
			} else { // 否则
				// println('J isb=$ved.is_building')
				ved.view.j() // j
				// if !ved.is_building {
				// ved.refresh = false
				// }
			}
		}
		.k { // k
			ved.view.k() // k
			// if !ved.is_building {
			// ved.refresh = false
			// }
		}
		.n { // n
			if ved.mode == .debugger { // 如果是调试器模式
				ved.debugger.step_over() // 单步执行
			} else if shift { // 如果 shift
				// backwards search
				// 向后搜索
				ved.search(.backward) // 搜索向后
			} else { // 否则
				ved.search(.forward) // 搜索向前
			}
		}
		.o { // o
			if shift_and_super { // 如果 shift 和 super
				ved.mode = .query // 设置模式
				ved.query_type = .open_workspace // 设置查询类型
				ved.query = '' // 设置查询
			} else if super { // 如果 super
				ved.mode = .query // 设置模式
				ved.query_type = .open // 设置查询类型
				ved.query = '' // 设置查询
				ved.just_switched = true // 设置 just_switched
				return // 返回
			} else if shift { // 如果 shift
				ved.view.shift_o() // shift_o
				ved.set_insert() // 设置插入
			} else { // 否则
				ved.view.o() // o
				ved.set_insert() // 设置插入
			}
		}
		.p { // p
			if shift_and_super { // 如果 shift 和 super
				ved.mode = .query // 设置模式
				ved.query_type = .alert // 设置查询类型
				ved.query = 'Running git pull...' // 设置查询
				ved.just_switched = true // 设置 just_switched
				spawn ved.git_pull() // 异步 git pull
				return // 返回
			} else if super { // 如果 super
				ved.mode = .query // 设置模式
				ved.query_type = .ctrlp // 设置查询类型
				ved.load_git_tree() // 加载 git 树
				ved.query = '' // 设置查询
				ved.just_switched = true // 设置 just_switched
				return // 返回
			} else { // 否则
				view.p() // p
			}
		}
		.r { // r
			if shift_and_super { // 如果 shift 和 super
				ved.query = '' // 设置查询
				ved.mode = .query // 设置模式
				ved.query_type = .run // 设置查询类型
				ved.just_switched = true // 设置 just_switched
			} else if super { // 如果 super
				view.reopen() // 重新打开
			} else { // 否则
				ved.prev_key = .r // 设置 prev_key
			}
		}
		.t { // t
			if super { // 如果 super
				// ved.timer.get_data(false)
				ved.timer.load_tasks() // 加载任务
				ved.mode = .timer // 设置模式
			} else { // 否则
				// if ved.prev_key == C.GLFW_KEY_T {
				view.tt() // tt
			}
		}
		.h { // h
			if shift { // 如果 shift
				ved.view.shift_h() // shift_h
			} else { // 否则
				ved.view.h() // h
			}
		}
		.l { // l
			if super { // 如果 super
				ved.just_switched = true // 设置 just_switched
				ved.view.save_file() // 保存文件
			} else if shift { // 如果 shift
				ved.view.move_to_page_bot() // 移动到页面底部
			} else { // 否则
				ved.view.l() // l
			}
		}
		.f6 {} // f6
		.g { // g
			// go to end
			// 转到末尾
			if shift && !super { // 如果 shift 且非 super
				ved.view.shift_g() // shift_g
				// ved.prev_key = 0
			}
			// copy file path to clipboard
			// 复制文件路径到剪贴板
			else if super { // 如果 super
				ved.cb.copy(ved.view.path) // 复制路径
			}
			// go to beginning
			// 转到开头
			else { // 否则
				if ved.prev_key == .g { // 如果 prev_key 是 g
					ved.prev_key = .invalid // 设置无效
					ved.view.gg() // gg
					// ved.prev_key = 0
				} else { // 否则
					ved.prev_key = .g // 设置 prev_key
				}
			}
			return // 返回
		}
		.f { // f
			if super { // 如果 super
				ved.view.shift_f() // shift_f
			}
		}
		.page_down { // page_down
			ved.view.shift_f() // shift_f
		}
		.page_up { // page_up
			ved.view.shift_b() // shift_b
		}
		.b { // b
			if shift_and_super { // 如果 shift 和 super
				ved.view.add_breakpoint(ved.view.y) // 添加断点
			} else if super { // 如果 super
				// force crash
				// 强制崩溃
				// # void*a = 0; int b = *(int*)a;
				ved.view.shift_b() // shift_b
			} else { // 否则
				if ved.prev_key == .d { // 如果 prev_key 是 d
					view.db(true) // db
				} else { // 否则
					ved.view.b() // b
				}
			}
		}
		.u { // u
			if shift_and_super { // 如果 shift 和 super
				ved.mode = .debugger // 设置模式
				ved.run_debugger(ved.view.breakpoints) // 运行调试器
			} else if super { // 如果 super
				ved.key_u() // key_u
			}
		}
		.v { // v
			ved.mode = .visual // 设置模式
			view.vstart = view.y // 设置 vstart
			view.vend = view.y // 设置 vend
		}
		.w { // w
			if ved.prev_key == .c { // 如果 prev_key 是 c
				view.cw() // cw
			} else if ved.prev_key == .d { // 如果 prev_key 是 d
				view.dw(true) // dw
			} else { // 否则
				view.w() // w
			}
		}
		.x { // x
			if super { // 如果 super
				// ctrl+x - decrease number
				// ctrl+x - 减少数字
				ved.view.super_a(-1) // super_a -1
				ved.prev_cmd = 'x' // 设置 prev_cmd
			} else { // 否则
				ved.view.delete_char() // 删除字符
			}
		}
		.y { // y
			if ved.prev_key == .y { // 如果 prev_key 是 y
				ved.view.yy() // yy
			}
			if super { // 如果 super
				spawn ved.build_app2() // 异步构建应用
			}
		}
		.z { // z
			if ved.prev_key == .z { // 如果 prev_key 是 z
				ved.view.zz() // zz
			}
			// Next workspace
			// 下一个工作区
		}
		// ]
		.right_bracket { // right_bracket
			if super { // 如果 super
				ved.open_workspace(ved.workspace_idx + 1) // 打开下一个工作区
			}
		}
		// [
		.left_bracket { // left_bracket
			if super { // 如果 super
				ved.open_workspace(ved.workspace_idx - 1) // 打开上一个工作区
			} else if ved.prev_key == .left_bracket { // 如果 prev_key 是 left_bracket
				ved.go_to_fn_start() // 转到函数开始
				println('[[ !!!!!') // 打印
			}
		}
		._8 { // 8
			if shift { // 如果 shift
				ved.star() // star
			}
		}
		._4 { // 4
			if shift { // 如果 shift
				view.dollar() // dollar
			}
		}
		._6 { // 6
			if shift { // 如果 shift
				view.shift_i() // shift_i
			}
		}
		.left { // left
			if ved.view.x > 0 { // 如果 x > 0
				ved.view.x-- // 减少 x
			}
		}
		.right { // right
			ved.view.l() // l
		}
		.up { // up
			ved.view.k() // k
			// ved.refresh = false
		}
		.down { // down
			ved.view.j() // j
			// ved.refresh = false
		}
		._5 { // 5
			if shift { // 如果 shift
				ved.pct() // pct
			}
		}
		else {} // 其他
	}
	if key != .r { // 如果 key 不是 r
		// otherwise R is triggered when we press C-R
		// 否则当按 C-R 时触发 R
		ved.prev_key = key // 设置 prev_key
	}
	if key == .q && super { // 如果 key 是 q 且 super
		ved.cq_in_a_row++ // 增加 cq_in_a_row
	} else { // 否则
		ved.cq_in_a_row = 0 // 重置
	}
	if ved.cq_in_a_row == 2 { // 如果 cq_in_a_row == 2
		exit(0) // 退出
	}
}

// on_char handles character input events.
// on_char 处理字符输入事件。
@[manualfree] // 手动释放
fn on_char(code u32, mut ved Ved) {
	$if macos { // 如果是 macos
		if ved.mode == .insert || ved.mode == .autocomplete { // 如果是插入或自动完成模式
			// In insert mode on macOS, we use the Native NSTextView bridge.
			// This avoids duplicate input and correctly handles IME.
			// 在 macOS 上的插入模式中，我们使用原生 NSTextView 桥接。
			// 这避免了重复输入并正确处理 IME。
			return // 返回
		}
	}
	mut buf := [5]u8{} // 缓冲区
	s := unsafe { utf32_to_str_no_malloc(code, mut &buf[0]) } // 转换为字符串
	if ved.just_switched { // 如果 just_switched
		ved.just_switched = false // 设置 false
		if s in ['i', 'a', 'o', 'I', 'A', 'O'] {
			return // 返回
		}
	}
	println('on_char s="${s}" code="${code}"') // 打印
	match ved.mode { // 匹配模式
		.insert, .autocomplete { // 插入或自动完成
			ved.char_insert(s) // 插入字符
		}
		.query { // 查询
			ved.gg_pos = -1 // 设置 gg_pos
			ved.char_query(s) // 查询字符
		}
		.normal { // 正常
			// on char on normal only for replace with r
			// 在正常模式下的字符仅用于 r 替换
			if !ved.just_switched && ved.prev_key == .r { // 如果 prev_key 是 r
				if s != 'r' { // 如果 s 不是 r
					ved.view.r(s) // r
					ved.prev_key = gg.KeyCode.invalid // 设置无效
					ved.prev_cmd = 'r' // 设置 prev_cmd
					ved.prev_insert = s.clone() // 克隆 prev_insert
				}
				return // 返回
			}
			ved.prev_key_str = s // for `ci(` etc, no `(` in gg.KeyCode // 设置 prev_key_str
		}
		else {} // 其他
	}
}

// key_insert handles key presses in insert mode.
// key_insert 处理插入模式下的按键。
fn (mut ved Ved) key_insert(key gg.KeyCode, mod gg.Modifier) {
	super := mod == .super || mod == .ctrl // 是否 super 或 ctrl
	// shift := mod == .shift
	match key { // 匹配 key
		.backspace { // backspace
			ved.just_switched = true // prevent backspace symbol being added in char handler // 设置 just_switched
			ved.view.backspace() // backspace
		}
		.enter { // enter
			if false && ved.mode == .autocomplete { // 如果是自动完成
				// Pressed enter in autocomplete mode, insert text from selected suggested field
				// 在自动完成模式下按 enter，插入选定建议字段的文本
				ved.insert_suggested_field() // 插入建议字段
			} else { // 否则
				ved.view.enter() // enter
			}
		}
		.escape { // escape
			ved.mode = .normal // 设置正常模式
		}
		.tab { // tab
			line := ved.view.line() // 获取行
			if line.ends_with('p ') { // 如果以 p 结束
				ved.view.insert_text("rintln('')") // 插入文本
				ved.view.x -= 2 // 减少 x
			} else { // 否则
				ved.view.insert_text('\t') // 插入制表符
			}
		}
		.left { // left
			if ved.view.x > 0 { // 如果 x > 0
				ved.view.x-- // 减少 x
			}
		}
		.right { // right
			ved.view.l() // l
		}
		.up { // up
			ved.view.k() // k
			// ved.refresh = false
		}
		.down { // down
			ved.view.j() // j
			// ved.refresh = false
		}
		else {} // 其他
	}
	if (key == .l || key == .s) && super { // 如果 (l 或 s) 且 super
		ved.view.save_file() // 保存文件
		ved.mode = .normal // 设置正常模式
		return // 返回
	}
	if super && key == .u { // 如果 super 且 u
		ved.mode = .normal // 设置正常模式
		ved.key_u() // key_u
		return // 返回
	}
	// Insert macro   TODO  customize
	// 插入宏 TODO 自定义
	if super && key == .g { // 如果 super 且 g
		ved.view.insert_text('<code></code>') // 插入文本
		ved.view.x -= 7 // 减少 x
	}
	// Autocomplete
	// 自动完成
	if key == .n && super { // 如果 n 且 super
		ved.ctrl_n()
		return
	}
	if key == .v && super { // 如果 v 且 super
		ved.view.insert_text(ved.cb.paste()) // 插入粘贴文本
		ved.just_switched = true // 设置 just_switched
	}
}

// char_insert inserts a character in insert mode.
// char_insert 在插入模式下插入字符。
fn (mut ved Ved) char_insert(s string) {
	if int(s[0]) < 32 { // 如果小于 32
		return // 返回
	}
	ved.view.insert_text(s) // 插入文本
	ved.prev_insert += s // 添加到 prev_insert
	// println(ved.prev_insert)
}

// key_visual handles key presses in visual mode.
// key_visual 处理视觉模式下的按键。
fn (mut ved Ved) key_visual(key gg.KeyCode, mod gg.Modifier) {
	super := mod == .super || mod == .ctrl // 是否 super 或 ctrl
	shift := mod == .shift // 是否 shift
	mut view := ved.view // 获取视图
	match key { // 匹配 key
		.j { // j
			view.vend++ // 增加 vend
			if view.vend >= view.lines.len { // 如果超出
				view.vend = view.lines.len - 1 // 设置为最后一行
			}
			// Scroll
			// 滚动
			if view.vend >= view.from + view.page_height { // 如果需要滚动
				view.from++ // 增加 from
			}
			ved.view.j() // Move the cursor down as well (mimics vim's behavior) // 也向下移动光标（模仿 vim 行为）
		}
		.k { // k
			if view.vend > 0 { // 如果 vend > 0
				view.vend-- // 减少 vend
			}
			ved.view.k() // Move the cursor up as well (mimics vim's behavior) // 也向上移动光标（模仿 vim 行为）
		}
		.y { // y
			view.y_visual() // y_visual
			ved.mode = .normal // 设置正常模式
		}
		.d { // d
			view.d_visual() // d_visual
			ved.mode = .normal // 设置正常模式
		}
		.q { // q
			if ved.prev_key == .g { // 如果 prev_key 是 g
				ved.view.gq() // gq
			}
		}
		.period { // .
			if shift { // 如果 shift
				// >
				ved.view.shift_right() // shift_right
			}
		}
		.comma { // ,
			if shift { // 如果 shift
				// <
				ved.view.shift_left() // shift_left
			}
		}
		._0 { // 0
			if !super { // 如果非 super
				view.zero() // zero
			}
		}
		._4 { // 4
			if shift { // 如果 shift
				view.dollar() // dollar
			}
		}
		._6 { // 6
			if shift { // 如果 shift
				view.shift_i() // shift_i
			}
		}
		.g { // g // Handle 'g' in visual mode // 处理视觉模式下的 g
			if shift { // G key // G 键
				// Select to end of file
				// 选择到文件末尾
				if view.lines.len > 0 { // 如果行数 > 0
					view.vend = view.lines.len - 1 // 设置 vend 为最后一行
					view.set_y(view.vend) // Move cursor to last line // 移动光标到最后一行
					// Scroll view to show the end
					// 滚动视图以显示末尾
					view.from = if view.vend > view.page_height { // 如果 vend > page_height
						view.vend - view.page_height + 1 // 设置 from
					} else { // 否则
						0 // 0
					}
				}
				ved.prev_key = .invalid // Reset potential double-key sequence // 重置潜在的双键序列
				return // 返回
			} else if ved.prev_key == .g { // gg key (Select to start of file) // gg 键（选择到文件开头）
				view.vend = 0 // Select up to the first line (index 0) // 选择到第一行（索引 0）
				view.set_y(0) // Move cursor to the first line // 移动光标到第一行
				view.from = 0 // Ensure the top of the file is visible // 确保文件顶部可见
				ved.prev_key = .invalid // Reset the double-key state // 重置双键状态
				return // 返回
			}
		}
		// Page Down handling
		// 页面向下处理
		.page_down, .f { // page_down, f
			if key == .f && !super { // 如果 f 且非 super
				// Only handle Ctrl+F for page down
				// 仅处理 Ctrl+F 用于页面向下
				return // 返回
			}
			view.shift_f() // Move view and cursor // 移动视图和光标
			view.vend = view.y // Extend selection to new cursor position // 扩展选择到新光标位置
		}
		// Page Up handling
		// 页面向上处理
		.page_up, .b { // page_up, b
			if key == .b && !super { // 如果 b 且非 super
				// Only handle Ctrl+B for page up
				// 仅处理 Ctrl+B 用于页面向上
				return // 返回
			}
			view.shift_b() // Move view and cursor // 移动视图和光标
			view.vend = view.y // Extend selection to new cursor position // 扩展选择到新光标位置
		}
		else {} // 其他
	} // end match key // 结束匹配 key

	// Default prev_key handling (only if the key wasn't part of a completed sequence like gg or G)
	// 默认 prev_key 处理（仅当键不是像 gg 或 G 这样的完成序列的一部分时）
	if key != .r { // Keep the existing check for 'r'
		ved.prev_key = key
	}
}
