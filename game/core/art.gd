class_name Art
extends RefCounted
## Texture + font lookup with a cache. Sprites live in res://assets/sprites/<name>.png.

static var _tex: Dictionary = {}
static var _font: Font
static var _small: Font

static func tex(n: String) -> Texture2D:
	if not _tex.has(n):
		var p := "res://assets/sprites/%s.png" % n
		if not ResourceLoader.exists(p):
			p = "res://assets/backgrounds/%s.jpg" % n
		_tex[n] = load(p) if ResourceLoader.exists(p) else null
		if _tex[n] == null:
			push_warning("missing art: " + n)
	return _tex[n]

static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/LuckiestGuy-Regular.ttf")
	return _font

static func small_font() -> Font:
	if _small == null:
		_small = load("res://assets/fonts/Inter-ExtraBold.otf")
	return _small

## A big outlined cartoon label (HUD, banners, bubbles).
static func label(text: String, size: int, color := Color.WHITE, outline := 14, outline_color := Color("1b1f3b")) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = outline_color
	ls.shadow_size = 0
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func small_label(text: String, size: int, color := Color.WHITE, outline := 8) -> Label:
	var l := label(text, size, color, outline)
	l.label_settings.font = small_font()
	return l
