module main // 主模块

import os // 导入 os 操作系统库
import gg // 导入 gg 图形库

struct Node { // Node 结构体，节点
mut:
	path     string // 路径
	is_dir   bool   // 是否为目录
	expanded bool   // 是否展开
	children []int  // 子节点索引数组
	depth    int    // 深度
}

struct Tree { // Tree 结构体，树
mut:
	nodes         []Node    // 节点数组
	visible_nodes []int     // 可见节点数组
	node_pos      []NodePos // 节点位置数组
	root          int       // 根节点
}

struct NodePos { // NodePos 结构体，节点位置
	node_idx int // 节点索引
	x        int // x 坐标
	y        int // y 坐标
	w        int // 宽度
	h        int // 高度
}

fn (mut t Tree) init(workspace_path string) { // init 函数，初始化树
	println('init tree workspace=${workspace_path}') // 打印初始化信息
	t.nodes.clear() // 清空节点
	t.nodes << Node{ // 添加根节点
		path:     workspace_path // 工作区路径
		is_dir:   true           // 是目录
		expanded: true           // false // 展开
		depth:    0              // 深度 0
	}
	t.root = 0 // 根节点索引
	t.load_children(t.root) // 加载子节点
	t.refresh() // 刷新
	// println('TTTT') // 打印（注释）
	// println(t) // 打印树（注释）
}

fn (mut t Tree) refresh() { // refresh 函数，刷新树
	t.compute_visible_nodes() // 计算可见节点
	t.compute_layout() // 计算布局
}

fn (mut t Tree) load_children(node_idx int) { // load_children 函数，加载子节点
	println('load children ${node_idx}') // 打印加载信息
	mut node := t.nodes[node_idx] // 获取节点
	println('node=${node}') // 打印节点
	if !node.is_dir || node.children.len > 0 { // 如果不是目录或已有子节点
		return // 返回
	}

	entries := os.ls(node.path) or { return } // 列出目录内容
	println('entries=${entries}') // 打印条目
	for entry in entries { // 循环条目
		full_path := os.join_path(node.path, entry) // 完整路径
		is_dir := os.is_dir(full_path) // 是否为目录
		t.nodes << Node{ // 添加节点
			path:   full_path // 路径
			is_dir: is_dir   // 是否目录
			depth:  node.depth + 1 // 深度加一
		}
		t.nodes[node_idx].children << t.nodes.len - 1 // 添加子节点索引
	}
}

fn (mut t Tree) compute_visible_nodes() { // compute_visible_nodes 函数，计算可见节点
	t.visible_nodes.clear() // 清空可见节点
	mut stack := []int{} // 栈
	stack << t.root // 压入根节点
	for stack.len > 0 { // 当栈不为空
		idx := stack.pop() // 弹出索引
		t.visible_nodes << idx // 添加到可见节点
		node := t.nodes[idx] // 获取节点
		if node.is_dir && node.expanded { // 如果是目录且展开
			for i := node.children.len - 1; i >= 0; i-- { // 循环子节点
				stack << node.children[i] // 压入子节点
			}
		}
	}
	println('visible afer compute') // 打印计算后可见
	println(t.visible_nodes) // 打印可见节点
}

fn (mut t Tree) handle_click(x int, y int) { // handle_click 函数，处理点击
	for pos in t.node_pos { // 循环节点位置
		if x >= pos.x && x <= pos.x + pos.w && y >= pos.y && y <= pos.y + pos.h { // 如果在范围内
			mut node := &t.nodes[pos.node_idx] // 获取节点引用
			if node.is_dir { // 如果是目录
				node.expanded = !node.expanded // 切换展开状态
				if node.expanded { // 如果展开
					t.load_children(pos.node_idx) // 加载子节点
				}
				t.refresh() // 刷新
			}
			break // 跳出
		}
	}
}

// Handle mouse clicks: // 处理鼠标点击
fn (mut ved Ved) on_click(x int, y int) { // on_click 函数，点击事件
	ved.tree.handle_click(x, y) // 处理树点击
}

// Initialize the tree when workspace is set: // 当设置工作区时初始化树
fn (mut ved Ved) init_tree() { // init_tree 函数，初始化树
	ved.tree.init(ved.workspace) // 初始化树
}

fn (mut t Tree) compute_layout() { // compute_layout 函数，计算布局
	t.node_pos.clear() // 清空节点位置
	mut y := 30 // y 坐标
	x := 10 // x 坐标
	for idx in t.visible_nodes { // 循环可见节点
		node := t.nodes[idx] // 获取节点
		indent := node.depth * 20 // 缩进
		current_x := x + indent // 当前 x 坐标
		text := os.base(node.path) // 文本
		w := text.len * 8 + 20 // Account for [+]/[-] symbol // 宽度，考虑 [+]/[-] 符号
		h := 20 // 高度
		t.node_pos << NodePos{idx, current_x, y, w, h} // 添加节点位置
		y += h // y 坐标增加
	}
}

fn (mut t Tree) draw(mut ved Ved) { // draw 函数，绘制树
	// println('draw tree') // 打印绘制树（注释）
	for pos in t.node_pos { // 循环节点位置
		node := t.nodes[pos.node_idx] // 获取节点
		text := os.base(node.path) // 文本
		if node.is_dir { // 如果是目录
			// Draw expand/collapse symbol // 绘制展开/折叠符号
			symbol := if node.expanded { '- ' } else { '+ ' } // 符号
			ved.gg.draw_text2(x: pos.x, y: pos.y, text: symbol, color: gg.black) // 绘制符号
			ved.gg.draw_text2(x: pos.x + 20, y: pos.y, text: text, color: gg.blue) // 绘制文本
		} else { // 否则
			ved.gg.draw_text2(x: pos.x + 20, y: pos.y, text: text, color: gg.black) // 绘制文本
		}
	}
}
