class_name ChronicleLog
extends RichTextLabel

signal day_exported(day: int, path: String)

const CHRONICLES_DIR := "res://chronicles"

var _day_lines: Array[String] = []

func _ready() -> void:
	bbcode_enabled = true

## never use `text +=` here — that reparses the whole accumulated BBCode
## string every call (O(n^2) over a long log). append_text() is incremental.
func add_line(text: String, color_hex: String) -> void:
	append_text("[color=#%s]%s[/color]\n" % [color_hex, text])
	scroll_to_line(get_line_count() - 1)
	_day_lines.append(text)

func finish_day(day: int, moral: String) -> void:
	if moral != "":
		append_text("\n[color=#f4c542][b]Day %d — %s[/b][/color]\n\n" % [day, moral])
		scroll_to_line(get_line_count() - 1)
	_export_markdown(day, moral)
	_day_lines.clear()
	clear() ## history already persisted to disk; the widget doesn't need to hold it

func _export_markdown(day: int, moral: String) -> void:
	if not DirAccess.dir_exists_absolute(CHRONICLES_DIR):
		DirAccess.make_dir_recursive_absolute(CHRONICLES_DIR)
	var path := "%s/day_%03d.md" % [CHRONICLES_DIR, day]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("chronicle export failed: %s" % FileAccess.get_open_error())
		return
	f.store_string("# Day %d\n\n" % day)
	for line in _day_lines:
		f.store_string("- %s\n" % line)
	if moral != "":
		f.store_string("\n> **Moral:** %s\n" % moral)
	f.close()
	day_exported.emit(day, path)
