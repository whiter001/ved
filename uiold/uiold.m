#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

/**
 * Ved Editor macOS Native Bridge
 * This file implements a hidden NSTextView to handle complex text input (like CJK IME)
 * and bridges macOS native events back to the V language core.
 */

typedef void (*ved_insert_text_fn)(void* user_data, const char* text);
typedef void (*ved_marked_text_fn)(void* user_data, const char* text);

// Global callbacks registered from V
static ved_insert_text_fn g_insert_cb = NULL;
static ved_marked_text_fn g_marked_cb = NULL;
static void* g_ved_ptr = NULL;

/**
 * VedImeView is a customized NSTextView that intercepts native text input events.
 * It is kept invisible and 1px wide to avoid interfering with Ved's own rendering,
 * while still providing a target for the macOS IME candidate window.
 */
@interface VedImeView : NSTextView
@end

@implementation VedImeView

/**
 * Called when text is finalized (e.g., user selects a candidate from IME or types directly).
 */
- (void)insertText:(id)string replacementRange:(NSRange)replacementRange {
    NSString *text = ([string isKindOfClass:[NSAttributedString class]]) ? [string string] : (NSString *)string;
    if (text.length > 0 && g_insert_cb) {
        g_insert_cb(g_ved_ptr, [text UTF8String]);
    }
    // Clear the internal marked text buffer on the V side
    if (g_marked_cb) {
        g_marked_cb(g_ved_ptr, "");
    }
    [self setString:@""];
    [self unmarkText];
}

/**
 * Called when the user is still composing text in IME (pre-edit/marked text).
 * We pass this to Ved to render it manually at the cursor position.
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
 * Intercepts various text commands (backspace, enter, arrow keys) when the native view is focused.
 */
- (void)doCommandBySelector:(SEL)selector {
    if (g_insert_cb) {
        if (selector == @selector(insertNewline:)) { g_insert_cb(g_ved_ptr, "[ENTER]"); return; }
        if (selector == @selector(deleteBackward:)) { g_insert_cb(g_ved_ptr, "[BACKSPACE]"); return; }
        if (selector == @selector(cancelOperation:)) { g_insert_cb(g_ved_ptr, "[ESC]"); return; }
        if (selector == @selector(insertTab:)) { g_insert_cb(g_ved_ptr, "[TAB]"); return; }
        
        // Map native movement commands to Ved's internal key strings
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
 * Crucial for IME: returns the screen coordinates where the candidate window should appear.
 * macOS uses this to position the little popup window for character selection.
 */
- (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(NSRangePointer)actualRange {
    NSRect frame = [self frame];
    NSRect screen_rect = [[self window] convertRectToScreen:frame];
    return screen_rect;
}

// Stubs for protocol compliance
- (NSUInteger)characterIndexForPoint:(NSPoint)point { return 0; }
- (NSAttributedString *)attributedSubstringForProposedRange:(NSRange)range actualRange:(NSRangePointer)actualRange { return nil; }
- (BOOL)hasMarkedText { return NO; }
- (NSRange)markedRange { return NSMakeRange(NSNotFound, 0); }
- (NSRange)selectedRange { return NSMakeRange(0, 0); }
- (NSArray<NSAttributedStringKey> *)validAttributesForMarkedText { return @[]; }

@end

static VedImeView* g_ime_view = nil;

/**
 * Initializes the macOS app environment and injects the hidden native input view.
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
            // We create a tiny 1x1 view. It's fully transparent to prevent visual overlap
            // with Ved's own custom-drawn text while still handling IME logic.
            g_ime_view = [[VedImeView alloc] initWithFrame:NSMakeRect(-10, -10, 1, 1)];
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

// Callback registration functions
void reg_ved_insert_cb(ved_insert_text_fn cb) { g_insert_cb = cb; }
void reg_ved_marked_cb(ved_marked_text_fn cb) { g_marked_cb = cb; }
void reg_ved_instance(void* ptr) { g_ved_ptr = ptr; }

/**
 * Updates the position of the native view to match Ved's internal cursor.
 * This ensures the IME candidate window appears right where the user is typing.
 */
void set_ime_position(int x, int y, int h) {
    if (!g_ime_view) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSWindow *window = [g_ime_view window];
        if (window) {
            NSRect content_rect = [[window contentView] frame];
            // macOS uses bottom-left origin, while Ved uses top-left.
            // We flip the Y coordinate and place the IME view below the cursor line.
            float flipped_y = content_rect.size.height - y;
            flipped_y -= h;
            [g_ime_view setFrame:NSMakeRect(x, flipped_y, 1, h)];
        }
    });
}

/**
 * Switches focus between the native input view (Insert Mode) and the main window (Normal Mode).
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
