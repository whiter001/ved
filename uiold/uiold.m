#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

typedef void (*ved_insert_text_fn)(const char* text);
static ved_insert_text_fn g_insert_cb = NULL;

@interface VedImeView : NSTextView
@end

@implementation VedImeView
// This is called when the user FINALLY commits the text (e.g. presses space or chooses a candidate)
- (void)insertText:(id)string replacementRange:(NSRange)replacementRange {
    NSString *text = ([string isKindOfClass:[NSAttributedString class]]) ? [string string] : (NSString *)string;
    
    // We only send the text to V if it's not empty.
    if (text.length > 0 && g_insert_cb) {
        printf("DEBUG: insertText (committed): %s\n", [text UTF8String]);
        g_insert_cb([text UTF8String]);
    }
    
    // Crucially, clear everything to avoid state accumulation
    [self setString:@""];
    [self unmarkText];
}

// This is called while the user is still typing pinyin
- (void)setMarkedText:(id)string selectedRange:(NSRange)selectedRange replacementRange:(NSRange)replacementRange {
    // We don't send marked text to V yet to avoid duplicates.
    // But we let super handle it so the system IME popup shows up correctly.
    [super setMarkedText:string selectedRange:selectedRange replacementRange:replacementRange];
}

// Handle special keys like Backspace, Enter, Esc while focused
- (void)doCommandBySelector:(SEL)selector {
    if (g_insert_cb) {
        if (selector == @selector(insertNewline:)) {
            g_insert_cb("[ENTER]");
            return;
        } else if (selector == @selector(deleteBackward:)) {
            g_insert_cb("[BACKSPACE]");
            return;
        } else if (selector == @selector(cancelOperation:)) { // ESC
            g_insert_cb("[ESC]");
            return;
        } else if (selector == @selector(insertTab:)) {
            g_insert_cb("[TAB]");
            return;
        }
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
            // Setup a proper container for the IME view
            g_ime_view = [[VedImeView alloc] initWithFrame:NSMakeRect(-10, -10, 1, 1)];
            [g_ime_view setEditable:YES];
            [g_ime_view setSelectable:YES];
            [[window contentView] addSubview:g_ime_view];
            puts("macOS App Environment Setup - Version 13 (Fine-grained IME)");
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
            NSRect frame = [[window contentView] frame];
            float flipped_y = frame.size.height - y - h;
            [g_ime_view setFrame:NSMakeRect(x, flipped_y, 100, h)];
        }
    });
}

void focus_native_input(bool focus) {
    if (!g_ime_view) return;
    dispatch_async(dispatch_get_main_queue(), ^{ 
        NSWindow *window = [g_ime_view window];
        if (window) {
            if (focus) {
                [window makeFirstResponder:g_ime_view];
            } else {
                [window makeFirstResponder:[window contentView]];
            }
        }
    });
}

void reg_key_ved2() {}
