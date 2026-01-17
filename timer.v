module main

// 主模块
import time // 导入 time 时间库
import gg // 导入 gg 图形库
import os // 导入 os 操作系统库
import strings // 导入 strings 字符串库

const time_cfg = gg.TextCfg{ // time_cfg 常量
	color: gg.gray // 颜色
	size:  14      // 大小
}

const color_distracting = gg.rgb(255, 111, 130) // color_distracting 常量，干扰色
const color_productive = gg.rgb(50, 90, 110) // gx.rgb(167,236,82) // color_productive 常量，生产力色
const color_neutral = gg.rgb(39, 195, 221) // color_neutral 常量，中性色

// Timer 结构体管理编辑器的番茄钟和时间追踪状态 // Timer struct manages the editor's pomodoro and time tracking state
struct Timer { // Timer 结构体
mut:
	gg             &gg.Context = unsafe { nil } // 图形上下文，用于绘制 UI // graphics context for drawing UI
	tasks          []Task    // 当前加载的任务列表 // currently loaded list of tasks
	date           time.Time // 当前正在显示的日期 // currently displayed date
	pom_start      i64       // 番茄钟开始的 Unix 时间戳 // unix timestamp when pomodoro started
	pom_is_started bool      // 番茄钟是否正在运行 // whether pomodoro is running
}

// Task 结构体代表一个独立的工作任务记录 // Task struct represents a single work task record
struct Task { // Task 结构体
	start        int      // 开始时间（自当天 00:00 起的分钟数） // start time in minutes from 00:00 of the day
	end          int      // 结束时间（自当天 00:00 起的分钟数） // end time in minutes from 00:00 of the day
	name         string   // 任务名称 // task name
	color        gg.Color // 任务显示的颜色（根据生产力区分） // color for task display (distinguished by productivity)
	duration     string   // 格式化的持续时间字符串 // formatted duration string
	duration_min int      // 持续时间的分钟数 // duration in minutes
	productive   bool     // 是否为生产力任务 // whether it's a productive task
}

// load_tasks 从本地任务记录文件中读取并解析指定日期的所有任务 // load_tasks reads and parses all tasks for the specified date from the local task records file
fn (mut t Timer) load_tasks() { // load_tasks 函数
	// println('timer.load_tasks()') // 打印（注释）
	lines := os.read_lines(tasks_path) or { return } // 读取行
	// println(lines) // 打印行（注释）
	mut tasks := []Task{} // 任务
	today := t.date.ymmdd() // 获取今天
	// println('day=$today') // 打印今天（注释）
	for line in lines { // 循环行
		// 仅处理包含分隔符且属于当前日期的行 // Only process lines that contain the separator and belong to the current date
		if !line.contains('|') { // 如果不包含 '|'
			continue // 继续
		}
		if !line.contains(today) { // 如果不包含今天
			continue // 继续
		}
		words_ := line.split('|') // 分割行
		words := words_.filter(it != '') // 过滤空字符串
		// println('wordss:') // 打印（注释）
		// println(words) // 打印单词（注释）
		if words.len != 4 { // 如果单词长度 != 4
			continue // 继续
		}
		time_ := words[2].trim_space() // 时间
		// println('time=$time') // 打印时间（注释）
		a := time_.split(' ') // 分割时间
		// println('a=') println(a) // 打印 a（注释）
		if a.len < 2 { // 如果 a 长度 < 2
			continue // 继续
		}
		b := a[1].split(':') // 分割 b
		// println('b=') println(b) // 打印 b（注释）
		if b.len < 2 { // 如果 b 长度 < 2
			continue // 继续
		}
		hour := b[0].int() // 小时
		min := b[1].int() // 分钟
		end_time := words[3] // 结束时间
		hhmm := end_time.split(':') // 分割 hhmm
		hour_end := hhmm[0].trim_space().int() // 结束小时
		min_end := hhmm[1].trim_space().int() // 结束分钟
		name := words[0].trim_space() // 名称
		duration := words[1].trim_space() // 持续时间
		productive := !name.starts_with('@') // 是否生产力
		color := if productive { color_productive } else { color_distracting } // 颜色
		// TODO autofree bug remove clone() // TODO autofree bug remove clone()
		name2 := if productive { name.clone() } else { name[1..] } // name2
		task := Task{ // 创建任务
			start:        hour * 60 + min         // 开始
			end:          hour_end * 60 + min_end // 结束
			name:         name2                   // 名称
			duration:     duration                // 持续时间
			duration_min: duration[..duration.len - 1].int() // 持续时间分钟
			color:        color      // 颜色
			productive:   productive // 是否生产力
		}
		// println('task:') // 打印任务（注释）
		// println(task) // 打印任务（注释）
		if task.end < task.start { // 如果结束 < 开始
			continue // 继续
		}
		tasks << task // 添加任务
	}
	// println('tasks.len=$tasks.len') // 打印任务长度（注释）
	t.tasks = tasks // 设置任务
}

fn new_timer(mut gg_ gg.Context) Timer { // new_timer 函数，新建计时器
	mut timer := Timer{ // 创建计时器
		gg:   gg_ // gg
		date: time.now() // 日期
	}
	timer.load_tasks() // 加载任务
	return timer // 返回计时器
}

// fn (mut t Timer) load_tasks() { // （注释）
// }
// draw 负责渲染计时器/番茄钟的图形界面 // draw is responsible for rendering the timer/pomodoro graphical interface
fn (mut t Timer) draw() { // draw 函数，绘制
	// 计算居中弹窗的尺寸和坐标 // Calculate dimensions and coordinates for centered popup
	window_width := t.gg.width / 2 // 窗口宽度
	window_height := t.gg.height - 20 // 窗口高度
	window_x := (t.gg.width - window_width) / 2 // 窗口 x
	window_y := (t.gg.height - window_height) / 2 // 窗口 y

	// 绘制背景 // Draw background
	t.gg.draw_rect_filled(window_x, window_y, window_width, window_height, gg.white) // 绘制填充矩形

	// 时间轴刻度计算：将 24 小时映射到窗口高度 // Time axis scale calculation: map 24 hours to window height
	hour_width := window_height / 24 // 每小时占据的高度 // Height occupied per hour
	scale := 60.0 / f64(hour_width) // 比例
	mut total := 0 // 总数

	// 绘制每个已加载的任务块 // Draw each loaded task block
	for task in t.tasks { // 循环任务
		// println('TASK $task') // 打印任务（注释）
		if task.duration.len < 3 { // 如果持续时间长度 < 3
			continue // 继续
		}
		x := f64(window_x) + 30.0 // x
		y := f64(window_y) + f64(task.start) / scale + 10 // y
		height := f64(task.end - task.start) / scale // 高度

		// 绘制代表任务持续时间的彩色矩形 // Draw colored rectangle representing task duration
		t.gg.draw_rect_filled(f32(x), f32(y), f32(hour_width), f32(height), task.color) // 绘制填充矩形

		// 绘制任务名称和持续时间文本 // Draw task name and duration text
		t.gg.draw_text(int(x) + hour_width + 10, int(y) + 5, task.name + ' ' + task.duration,
			gg.TextCfg{ // 文本配置
			color: task.color // 颜色
		})
		if task.productive { // 如果生产力
			total += task.duration_min
		}
	}

	// 绘制 24 小时时间轴的横线和小时标签
	for hour in 0 .. 24 + 1 {
		hour_y := window_y + hour * hour_width + 10
		hour_x := window_x + 30
		if hour < 24 {
			t.gg.draw_text(hour_x - 25, hour_y + 10, '${hour:02d}', time_cfg)
		}
		t.gg.draw_line(hour_x, hour_y, hour_x + hour_width, hour_y, gg.gray)
	}

	// 绘制左侧垂直基准线
	t.gg.draw_line(window_x + 30, window_y + 10, window_x + 30, window_y + 10 + 24 * hour_width,
		gg.gray)
	// 绘制右侧垂直基准线（时间轴宽度）
	t.gg.draw_line(window_x + 30 + hour_width, window_y + 10, window_x + 30 + hour_width,
		window_y + 10 + 24 * hour_width, gg.gray)

	// 在右上角绘制当前查看的日期
	t.gg.draw_text_def(window_x + window_width - 100, 20, t.date.ymmdd())

	// 显示当日生产力任务的总计时间
	h := total / 60
	m := total % 60
	t.gg.draw_text(window_x + window_width - 100, 100, '${h}:${m:02d}', gg.TextCfg{
		color: color_productive
	})
}

fn (mut timer Timer) key_down(key gg.KeyCode, super bool) {
	match key {
		.up, .k {
			timer.date = timer.date.add_days(-1)
			timer.load_tasks()
		}
		.down, .j {
			timer.date = timer.date.add_days(1)
			timer.load_tasks()
		}
		.f {
			// start 25 min pomodoro timer
			timer.pom_start = time.now().local_unix()
			timer.pom_is_started = true
		}
		else {}
	}
}

fn lock_screen() {
	$if macos {
		// os.system('pmset displaysleepnow')
	}
}

fn (ved &Ved) pomodoro_minutes() int {
	return int((ved.now.local_unix() - ved.timer.pom_start) / 60)
}

const max_task_len = 40
const separator = '|-----------------------------------------------------------------------------|'

// insert_task 将当前完成的任务持久化存储到本地文件系统
fn (ved &Ved) insert_task() ! {
	// 如果任务名为空或持续时间不足 1 分钟，则不记录
	if ved.cur_task == '' || ved.task_minutes() == 0 {
		return
	}
	start_time := time.unix(int(ved.task_start_unix))
	mut f := os.open_append(tasks_path)!

	// 格式化任务名，限制长度并填充空格以保持对齐
	task_name := ved.cur_task.limit(max_task_len) +
		strings.repeat(` `, max_task_len - ved.cur_task.len)

	mut mins := ved.task_minutes().str() + 'm'
	// 防止意外情况：如果单次任务超过 8 小时，可能忘记点结束，仅记录 60 分钟
	too_long := ved.task_minutes() > 60 * 8
	if too_long {
		mins = '60m'
	}
	mins_pad := strings.repeat(` `, 4 - mins.len)
	now := time.now()

	// 处理任务写入：判断任务是否在同一天内完成
	if (start_time.day == now.day && start_time.month == now.month) || too_long {
		// 情况 A：同一天完成的任务，直接记录一条
		f.writeln('| ${task_name} | ${mins} ${mins_pad} | ' + start_time.format() + ' | ' +
			time.now().hhmm() + ' |')!
	} else {
		// 情况 B：跨天任务（例如从深夜 23:30 到凌晨 00:30）
		// 系统会将其拆分为两条记录，一条结束于 23:59，另一条从次日 00:00 开始
		midnight := time.Time{
			year:   start_time.year
			month:  start_time.month
			day:    start_time.day
			hour:   23
			minute: 59
		}
		day_start := time.Time{
			year:   now.year
			month:  now.month
			day:    now.day
			hour:   0
			minute: 0
		}

		f.writeln('| ${task_name} | ${mins} ${mins_pad} | ' + start_time.format() + ' | ' +
			midnight.hhmm() + ' |')!
		f.writeln(separator)! // 写入分隔线
		f.writeln('| ${task_name} | ${mins} ${mins_pad} | ' + day_start.format() + ' | ' +
			time.now().hhmm() + ' |')!
	}
	f.writeln(separator)!
	f.close()
}
