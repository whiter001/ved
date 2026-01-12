module main

fn nr_spaces_and_tabs_in_line(line string) (int, int) {
	mut nr_spaces := 0
	mut nr_tabs := 0
	mut i := 0
	for i < line.len && (line[i] == ` ` || line[i] == `\t`) {
		if line[i] == ` ` {
			nr_spaces++
		}
		if line[i] == `\t` {
			nr_tabs++
		}
		i++
	}
	return nr_spaces, nr_tabs
}

// rune_width returns the visual width of a rune (1 for ASCII, 2 for CJK/wide characters).
fn rune_width(r rune) int {
	if int(r) < 128 {
		return 1
	}
	// Basic CJK Unified Ideographs range
	if int(r) >= 0x4E00 && int(r) <= 0x9FFF {
		return 2
	}
	// Fullwidth forms etc.
	if int(r) >= 0xFF00 && int(r) <= 0xFFEF {
		return 2
	}
	return 1
}

// string_width returns the total visual width of a string.
fn string_width(s string) int {
	mut width := 0
	runes := s.runes()
	for r in runes {
		width += rune_width(r)
	}
	return width
}
