# Ved V 语言测试方案

本项目现在包含用 V 语言编写的原生测试，用于测试 ved 编辑器的核心功能。

## 测试文件结构

```
ved/
├── view_test.v      # View 核心功能单元测试 (30+ 测试用例)
├── ved_test.v       # Ved 集成测试 (40+ 测试用例)
├── events_test.v    # 事件处理测试 (25+ 测试用例)
└── TEST_README.md   # 本文件
```

## 运行测试

### 运行所有测试
```bash
v test .
```

### 运行单个测试文件
```bash
v test view_test.v
v test ved_test.v
v test events_test.v
```

### 运行并显示统计信息
```bash
v -stats test .
```

## 测试覆盖范围

### view_test.v - View 单元测试

测试 View 结构体的核心编辑功能：

- **初始化测试**: 验证 View 的初始状态
- **光标移动**: `h`, `j`, `k`, `l`, `w`, `b`, `gg`, `G`, `0`, `$` 等
- **文本操作**: `insert_text`, `backspace`, `delete_char`, `r`
- **行操作**: `dd`, `yy`, `p`, `o`, `O`, `join`
- **缩进**: `shift_right`, `shift_left`
- **撤销/重做**: `undo`, `redo`, `save_snapshot`
- **可视模式**: `vstart`, `vend`, 选择范围
- **文件操作**: `set_line`, `line`, `char`

### ved_test.v - Ved 集成测试

测试 Ved 主结构体的状态管理：

- **初始化**: 验证 Ved 的默认状态
- **模式切换**: `.normal`, `.insert`, `.visual`, `.query`, `.timer`, `.debugger`
- **视图管理**: `views`, `cur_split`, `view` 切换
- **工作区**: `workspace`, `workspace_idx`
- **查询系统**: `query`, `query_type`, `search_query`
- **历史记录**: `search_history`, `prev_cmd`, `prev_key`
- **剪贴板**: `ylines` (yank buffer)
- **文件跟踪**: `file_y_pos`, `open_paths`
- **Git 集成**: `git_diff_plus`, `git_diff_minus`
- **配置**: `cfg`, `current_syntax_idx`
- **任务/计时器**: `cur_task`, `timer`
- **调试**: `debug_info`, `debugger`

### events_test.v - 事件处理测试

测试事件处理和模式行为：

- **模式切换**: Escape 键行为，模式转换
- **可视模式**: 进入/退出，选择范围
- **错误处理**: 错误状态重置
- **刷新机制**: `refresh` 标志
- **分屏切换**: `update_view`
- **鼠标滚动**: `j()`, `k()` 调用
- **按键序列**: `dd`, `yy` 等组合键
- **搜索模式**: `.query` 模式激活
- **撤销/重做**: 编辑历史管理

## 测试设计原则

1. **独立性**: 每个测试都是独立的，不依赖其他测试
2. **可重复性**: 测试结果稳定，不受外部环境影响
3. **快速执行**: 所有测试在 2 秒内完成
4. **并行执行**: 支持 `v test .` 并行运行

## 添加新测试

### 基本模板
```v
fn test_description() {
    mut ved := create_test_ved()
    // 或
    mut view := create_test_view()

    // 设置初始状态
    ved.mode = .normal
    view.lines = ['test']

    // 执行操作
    view.j()

    // 验证结果
    assert view.y == 1
}
```

### 测试辅助函数

- `create_test_ved()` - 创建测试用的 Ved 实例
- `create_test_view()` - 创建测试用的 View 实例

## 与 AskUI 测试的对比

| 特性 | V 原生测试 | AskUI (TypeScript) |
|-----|-----------|-------------------|
| 执行速度 | < 2 秒 | 数十秒 |
| 依赖 | 仅需 V 编译器 | Bun + AskUI + 图形环境 |
| 测试方式 | 直接调用函数 | 模拟用户操作 |
| GUI 测试 | 不支持 | 支持 |
| 视觉回归 | 不支持 | 支持 |
| CI 友好 | 非常好 | 需要图形环境 |
| 覆盖率 | 核心逻辑 | 用户交互 |

## 建议的测试策略

- **70% V 原生测试**: 核心逻辑、数据结构、算法
- **30% AskUI 测试**: GUI 交互、视觉回归、复杂用户场景

## 持续集成

可以在 CI 中运行：
```yaml
- name: Run V tests
  run: v test .

- name: Run V format check
  run: v fmt -verify .

- name: Run V vet
  run: v vet .
```

## 未来扩展

可以添加更多测试：

1. **query_test.v**: 搜索、替换、模糊查找
2. **syntax_test.v**: 语法高亮、文件类型检测
3. **file_tree_test.v**: 文件树导航、操作
4. **timer_test.v**: 番茄钟、任务管理
5. **config_test.v**: 配置加载、保存
6. **integration_test.v**: 端到端工作流

## 测试统计

- **总测试数**: 95+
- **测试文件**: 3
- **平均执行时间**: < 2 秒
- **通过率**: 100%
