module main

import time
import gg
import os
import strings

const time_cfg = gg.TextCfg{
	color: gg.gray
	size:  14
}

const color_distracting = gg.rgb(255, 111, 130)
const color_productive = gg.rgb(50, 90, 110) // gx.rgb(167,236,82)
const color_neutral = gg.rgb(39, 195, 221)

// Timer 结构体管理编辑器的番茄钟和时间追踪状态
struct Timer {
mut:
	gg             &gg.Context = unsafe { nil } // 图形上下文，用于绘制 UI
	tasks          []Task                      // 当前加载的任务列表
	date           time.Time                   // 当前正在显示的日期
	pom_start      i64                       // 番茄钟开始的 Unix 时间戳
	pom_is_started bool                      // 番茄钟是否正在运行
}

// Task 结构体代表一个独立的工作任务记录
struct Task {
	start        int      // 开始时间（自当天 00:00 起的分钟数）
	end          int      // 结束时间（自当天 00:00 起的分钟数）
	name         string   // 任务名称
	color        gg.Color // 任务显示的颜色（根据生产力区分）
	duration     string   // 格式化的持续时间字符串
	duration_min int      // 持续时间的分钟数
	productive   bool     // 是否为生产力任务
}

// load_tasks 从本地任务记录文件中读取并解析指定日期的所有任务
fn (mut t Timer) load_tasks() {
	// println('timer.load_tasks()')
	lines := os.read_lines(tasks_path) or { return }
	// println(lines)
	mut tasks := []Task{}
	today := t.date.ymmdd() // 获取当前查看日期的字符串格式，如 "20260110"
	// println('day=$today')
	for line in lines {
		// 仅处理包含分隔符且属于当前日期的行
		if !line.contains('|') {
			continue
		}
		if !line.contains(today) {
			continue
		}
		words_ := line.split('|')
		words := words_.filter(it != '')
		// println('wordss:')
		// println(words)
		if words.len != 4 {
			continue
		}
		time_ := words[2].trim_space()
		// println('time=$time')
		a := time_.split(' ')
		// println('a=') println(a)
		if a.len < 2 {
			continue
		}
		b := a[1].split(':')
		// println('b=') println(b)
		if b.len < 2 {
			continue
		}
		hour := b[0].int()
		min := b[1].int()
		end_time := words[3]
		hhmm := end_time.split(':')
		hour_end := hhmm[0].trim_space().int()
		min_end := hhmm[1].trim_space().int()
		name := words[0].trim_space()
		duration := words[1].trim_space()
		productive := !name.starts_with('@')
		color := if productive { color_productive } else { color_distracting }
		// TODO autofree bug remove clone()
		name2 := if productive { name.clone() } else { name[1..] }
		task := Task{
			start:        hour * 60 + min
			end:          hour_end * 60 + min_end
			name:         name2
			duration:     duration
			duration_min: duration[..duration.len - 1].int()
			color:        color
			productive:   productive
		}
		// println('task:')
		// println(task)
		if task.end < task.start {
			continue
		}
		tasks << task
	}
	// println('tasks.len=$tasks.len')
	t.tasks = tasks
}

fn new_timer(mut gg_ gg.Context) Timer {
	mut timer := Timer{
		gg:   gg_
		date: time.now()
	}
	timer.load_tasks()
	return timer
}

// fn (mut t Timer) load_tasks() {
// }
// draw 负责渲染计时器/番茄钟的图形界面
fn (mut t Timer) draw() {
	// 计算居中弹窗的尺寸和坐标
	window_width := t.gg.width / 2
	window_height := t.gg.height - 20
	window_x := (t.gg.width - window_width) / 2
	window_y := (t.gg.height - window_height) / 2
	
	// 绘制背景
	t.gg.draw_rect_filled(window_x, window_y, window_width, window_height, gg.white)
	
	// 时间轴刻度计算：将 24 小时映射到窗口高度
	hour_width := window_height / 24 // 每小时占据的高度
	scale := 60.0 / f64(hour_width)
	mut total := 0
	
	// 绘制每个已加载的任务块
	for task in t.tasks {
		// println('TASK $task')
		if task.duration.len < 3 {
			continue
		}
		x := f64(window_x) + 30.0
		y := f64(window_y) + f64(task.start) / scale + 10
		height := f64(task.end - task.start) / scale
		
		// 绘制代表任务持续时间的彩色矩形
		t.gg.draw_rect_filled(f32(x), f32(y), f32(hour_width), f32(height), task.color)
		
		// 绘制任务名称和持续时间文本
		t.gg.draw_text(int(x) + hour_width + 10, int(y) + 5, task.name + ' ' + task.duration,
			gg.TextCfg{
			color: task.color
		})
		if task.productive {
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
