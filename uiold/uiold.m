#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

/**
 * Ved 编辑器 macOS 原生桥接
 * 此文件实现了一个隐藏的 NSTextView 以处理复杂的文本输入（如 CJK 输入法）
 * 并将 macOS 原生事件桥接到 V 语言核心。
 */

typedef void (*ved_insert_text_fn)(void* user_data, const char* text);
typedef void (*ved_marked_text_fn)(void* user_data, const char* text);

// 从 V 注册的全局回调
static ved_insert_text_fn g_insert_cb = NULL;
static ved_marked_text_fn g_marked_cb = NULL;
static void* g_ved_ptr = NULL;

/**
 * VedImeView 是一个定制的 NSTextView，用于拦截原生文本输入事件。
 * 它被保持不可见，以避免干扰 Ved 自身的渲染，同时仍为 macOS 输入法候选窗口提供目标。
 */
@interface VedImeView : NSTextView
@end

@implementation VedImeView

/**
 * 当文本最终确定时调用（例如，用户从输入法选择候选词或直接键入）。
 */
- (void)insertText:(id)string replacementRange:(NSRange)replacementRange {
    NSString *text = ([string isKindOfClass:[NSAttributedString class]]) ? [string string] : (NSString *)string;
    if (text.length > 0 && g_insert_cb) {
        g_insert_cb(g_ved_ptr, [text UTF8String]);
    }
    // 清除 V 端的内部标记文本缓冲区
    if (g_marked_cb) {
        g_marked_cb(g_ved_ptr, "");
    }
    [self setString:@""];
    [self unmarkText];
}

/**
 * 当用户仍在输入法中撰写文本时调用（预编辑/标记文本）。
 * 我们将其传递给 Ved，以便在光标位置手动渲染。
 */
- (void)setMarkedText:(id)string selectedRange:(NSRange)selectedRange replacementRange:(NSRange)replacementRange {
    [super setMarkedText:string selectedRange:selectedRange replacementRange:replacementRange];
    NSString *text = ([string isKindOfClass:[NSAttributedString class]]) ? [string string] : (NSString *)string;
    if (g_marked_cb) {
        g_marked_cb(g_ved_ptr, [text UTF8String]);
    }
}

- (void)unmarkText {
    [super unmarkText];
    if (g_marked_cb) {
        g_marked_cb(g_ved_ptr, "");
    }
}

/**
 * 当原生视图获得焦点时拦截各种文本命令（退格、回车、方向键）。
 */
- (void)doCommandBySelector:(SEL)selector {
    if (g_insert_cb) {
        if (selector == @selector(insertNewline:)) { g_insert_cb(g_ved_ptr, "[ENTER]"); return; }
        if (selector == @selector(deleteBackward:)) { g_insert_cb(g_ved_ptr, "[BACKSPACE]"); return; }
        if (selector == @selector(cancelOperation:)) { g_insert_cb(g_ved_ptr, "[ESC]"); return; }
        if (selector == @selector(insertTab:)) { g_insert_cb(g_ved_ptr, "[TAB]"); return; }
        
        // 将原生移动命令映射到 Ved 的内部键字符串
        if (selector == @selector(moveUp:)) { g_insert_cb(g_ved_ptr, "[UP]"); return; }
        if (selector == @selector(moveDown:)) { g_insert_cb(g_ved_ptr, "[DOWN]"); return; }
        if (selector == @selector(moveLeft:)) { g_insert_cb(g_ved_ptr, "[LEFT]"); return; }
        if (selector == @selector(moveRight:)) { g_insert_cb(g_ved_ptr, "[RIGHT]"); return; }
        if (selector == @selector(moveToBeginningOfLine:)) { g_insert_cb(g_ved_ptr, "[HOME]"); return; }
        if (selector == @selector(moveToEndOfLine:)) { g_insert_cb(g_ved_ptr, "[END]"); return; }
        if (selector == @selector(scrollPageUp:)) { g_insert_cb(g_ved_ptr, "[PGUP]"); return; }
        if (selector == @selector(scrollPageDown:)) { g_insert_cb(g_ved_ptr, "[PGDN]"); return; }
    }
    [super doCommandBySelector:selector];
}

- (BOOL)canBecomeKeyView { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }

/**
 * 对输入法至关重要：返回候选窗口应出现的屏幕坐标。
 * macOS 使用它来定位用于字符选择的小弹出窗口。
 */
- (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(NSRangePointer)actualRange {
    // 我们使用视图的整个范围，该视图位于光标处。
    // 这为不同的输入法提供了更稳定的目标。
    NSRect rect = [self bounds];
    if (actualRange) *actualRange = range;
    
    // 将视图坐标转换为窗口坐标，然后转换为屏幕坐标。
    NSRect window_rect = [self convertRect:rect toView:nil];
    NSRect screen_rect = [[self window] convertRectToScreen:window_rect];
    return screen_rect;
}

// 移除不正确的 stub，让 NSTextView 正常处理标记文本状态。
// 这允许操作系统正确跟踪撰写范围。

@end

static VedImeView* g_ime_view = nil;

/**
 * 初始化 macOS 应用程序环境并注入隐藏的原生输入视图。
 */
void setup_mac_app() {
    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];
    [[NSProcessInfo processInfo] setProcessName:@"Ved"];
    [app finishLaunching];
    [app activateIgnoringOtherApps:YES];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSWindow *window = [[NSApplication sharedApplication] keyWindow];
        if (window) {
            // 我们创建了一个微小但足够的视图（例如宽度为 200px）。
            // 它是完全透明的，以防止与 Ved 自身自定义绘制的文本发生视觉重叠。
            // 大于 1px 的宽度有助于复杂的输入法更可靠地计算弹出位置。
            g_ime_view = [[VedImeView alloc] initWithFrame:NSMakeRect(-500, -500, 200, 20)];
            [g_ime_view setEditable:YES];
            [g_ime_view setDrawsBackground:NO];
            [g_ime_view setBackgroundColor:[NSColor clearColor]];
            [g_ime_view setTextColor:[NSColor clearColor]];
            [g_ime_view setInsertionPointColor:[NSColor clearColor]];
            [[window contentView] addSubview:g_ime_view];
            puts("macOS App Environment Setup - Version 14 (Full Control Bridge)");
        }
    });
}

// 回调注册函数
void reg_ved_insert_cb(ved_insert_text_fn cb) { g_insert_cb = cb; }
void reg_ved_marked_cb(ved_marked_text_fn cb) { g_marked_cb = cb; }
void reg_ved_instance(void* ptr) { g_ved_ptr = ptr; }

/**
 * 更新原生视图的位置以匹配 Ved 的内部光标。
 * 这确保了输入法候选窗口出现在用户正在键入的位置。
 */
void set_ime_position(int x, int y, int h) {
    if (!g_ime_view) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSWindow *window = [g_ime_view window];
        if (window) {
            NSRect content_rect = [[window contentView] frame];
            // macOS 使用左下角原点，而 Ved 使用左上角。
            // 我们翻转 Y 坐标并将输入法视图放置在光标行下方。
            float flipped_y = content_rect.size.height - y;
            flipped_y -= h;
            // 使用 200px 宽度为输入法提供更稳定的撰写区域。
            [g_ime_view setFrame:NSMakeRect(x, flipped_y, 200, h)];
        }
    });
}

/**
 * 在原生输入视图（插入模式）和主窗口（正常模式）之间切换焦点。
 */
void focus_native_input(bool focus) {
    if (!g_ime_view) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSWindow *window = [g_ime_view window];
        if (window) {
            if (focus) [window makeFirstResponder:g_ime_view];
            else [window makeFirstResponder:[window contentView]];
        }
    });
}

void reg_key_ved2() {}
