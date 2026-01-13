#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

typedef void (*ved_insert_text_fn)(const char* text);
static ved_insert_text_fn g_insert_cb = NULL;

@interface VedImeView : NSTextView
@end

@implementation VedImeView
- (void)insertText:(id)string replacementRange:(NSRange)replacementRange {
    NSString *text = ([string isKindOfClass:[NSAttributedString class]]) ? [string string] : (NSString *)string;
    if (text.length > 0 && g_insert_cb) {
        g_insert_cb([text UTF8String]);
    }
    [self setString:@""];
    [self unmarkText];
}

- (void)setMarkedText:(id)string selectedRange:(NSRange)selectedRange replacementRange:(NSRange)replacementRange {
    [super setMarkedText:string selectedRange:selectedRange replacementRange:replacementRange];
    // Optional: could send marked text to V here for preview
}

- (void)doCommandBySelector:(SEL)selector {
    if (g_insert_cb) {
        if (selector == @selector(insertNewline:)) { g_insert_cb("[ENTER]"); return; }
        if (selector == @selector(deleteBackward:)) { g_insert_cb("[BACKSPACE]"); return; }
        if (selector == @selector(cancelOperation:)) { g_insert_cb("[ESC]"); return; }
        if (selector == @selector(insertTab:)) { g_insert_cb("[TAB]"); return; }
        
        // Movement keys
        if (selector == @selector(moveUp:)) { g_insert_cb("[UP]"); return; }
        if (selector == @selector(moveDown:)) { g_insert_cb("[DOWN]"); return; }
        if (selector == @selector(moveLeft:)) { g_insert_cb("[LEFT]"); return; }
        if (selector == @selector(moveRight:)) { g_insert_cb("[RIGHT]"); return; }
        if (selector == @selector(moveToBeginningOfLine:)) { g_insert_cb("[HOME]"); return; }
        if (selector == @selector(moveToEndOfLine:)) { g_insert_cb("[END]"); return; }
        if (selector == @selector(scrollPageUp:)) { g_insert_cb("[PGUP]"); return; }
        if (selector == @selector(scrollPageDown:)) { g_insert_cb("[PGDN]"); return; }
    }
    [super doCommandBySelector:selector];
}

- (BOOL)canBecomeKeyView { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
@end

static VedImeView* g_ime_view = nil;

void setup_mac_app() {
    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];
    [[NSProcessInfo processInfo] setProcessName:@"Ved"];
    [app finishLaunching];
    [app activateIgnoringOtherApps:YES];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSWindow *window = [[NSApplication sharedApplication] keyWindow];
        if (window) {
            g_ime_view = [[VedImeView alloc] initWithFrame:NSMakeRect(-10, -10, 1, 1)];
            [g_ime_view setEditable:YES];
            [[window contentView] addSubview:g_ime_view];
            puts("macOS App Environment Setup - Version 14 (Full Control Bridge)");
        }
    });
}

void reg_ved_insert_cb(ved_insert_text_fn cb) {
    g_insert_cb = cb;
}

void set_ime_position(int x, int y, int h) {
    if (!g_ime_view) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSWindow *window = [g_ime_view window];
        if (window) {
            NSRect content_rect = [[window contentView] frame];
            // macOS Y is bottom-up. Ved Y is top-down.
            // Adjusting for line height to put candidate window UNDER the text
            float flipped_y = content_rect.size.height - y;
            [g_ime_view setFrame:NSMakeRect(x, flipped_y, 100, h)];
        }
    });
}

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