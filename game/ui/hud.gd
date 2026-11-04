class_name Hud
extends CanvasLayer
## Minimal HUD: floor (top left), score + high score (top centre), lives (top right), pause + mute buttons,
## a vertical progress bar on the left edge (department colours), department welcome banners
## (top of screen, never over the player) and the MANAGER timer while promoted.

signal pause_pressed
signal mute_pressed

var _root: Control
var _floor_l: Label
var _dept_l: Label
var _score_l: Label
var _hi_l: Label
var _lives: HBoxContainer
var _bar: Control
var _progress := 0.0
var _banner: Control
var _promo: Label
var _mute_btn: Button
var _hint: Label

func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var top := ColorRect.new()
	top.color = Color(0.07, 0.08, 0.18, 0.55)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, 170)
	top.size.y = 170
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	# floor
	_floor_l = Art.label("FLOOR 0", 58, Color.WHITE, 12)
	_floor_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_floor_l.position = Vector2(28, 22)
	_floor_l.size = Vector2(330, 70)
	_root.add_child(_floor_l)
	_dept_l = Art.small_label("LOBBY", 30, Color("ffd34a"), 7)
	_dept_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dept_l.position = Vector2(30, 96)
	_dept_l.size = Vector2(360, 44)
	_root.add_child(_dept_l)
	# score
	_score_l = Art.label("0", 76, Color("ffe14d"), 14)
	_score_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_score_l.position = Vector2(-200, 14)
	_score_l.size = Vector2(400, 90)
	_root.add_child(_score_l)
	_hi_l = Art.small_label("HI 0", 28, Color(1, 1, 1, 0.85), 6)
	_hi_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hi_l.position = Vector2(-200, 104)
	_hi_l.size = Vector2(400, 40)
	_root.add_child(_hi_l)
	# lives
	_lives = HBoxContainer.new()
	_lives.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_lives.position = Vector2(-290, 18)
	_lives.size = Vector2(270, 90)
	_lives.alignment = BoxContainer.ALIGNMENT_END
	_lives.add_theme_constant_override("separation", 6)
	_lives.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_lives)
	# buttons (below the lives)
	var pause := _round_button("II")
	pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause.position = Vector2(-124, 190)
	pause.pressed.connect(func(): pause_pressed.emit())
	_root.add_child(pause)
	_mute_btn = _round_button("")
	_mute_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mute_btn.position = Vector2(-124, 310)
	_mute_btn.pressed.connect(func(): mute_pressed.emit())
	_root.add_child(_mute_btn)
	refresh_mute()
	# progress bar
	_bar = Control.new()
	_bar.position = Vector2(18, 210)
	_bar.size = Vector2(44, 900)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	_root.add_child(_bar)
	# promo timer
	_promo = Art.label("", 44, Color("ffd34a"), 12)
	_promo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_promo.position = Vector2(-300, 175)
	_promo.size = Vector2(600, 60)
	_root.add_child(_promo)
	_hint = Art.label("DRAG ANYWHERE TO CLIMB", 50, Color.WHITE, 12)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-450, -170)
	_hint.size = Vector2(900, 70)
	_root.add_child(_hint)

func _round_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(100, 100)
	b.size = Vector2(100, 100)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Art.font())
	b.add_theme_font_size_override("font_size", 44)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.12, 0.28, 0.75) if st != "pressed" else Color(0.3, 0.35, 0.6, 0.9)
		sb.set_corner_radius_all(50)
		sb.set_border_width_all(5)
		sb.border_color = Color(1, 1, 1, 0.85)
		b.add_theme_stylebox_override(st, sb)
	return b

func refresh_mute() -> void:
	_mute_btn.text = "x" if Save.muted else "(("
	_mute_btn.modulate = Color(1, 0.6, 0.6) if Save.muted else Color.WHITE

func set_score(s: int, hi: int) -> void:
	_score_l.text = _fmt(s)
	_hi_l.text = "HI " + _fmt(maxi(s, hi))

func bump_score() -> void:
	_score_l.pivot_offset = _score_l.size * 0.5
	var t := create_tween()
	t.tween_property(_score_l, "scale", Vector2.ONE * 1.15, 0.05)
	t.tween_property(_score_l, "scale", Vector2.ONE, 0.1)

static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out

func set_floor(f: int, dept_name: String, col: Color) -> void:
	_floor_l.text = "FLOOR %d" % f if f > 0 else "LOBBY"
	if f > Cfg.FLOORS:
		_floor_l.text = "ROOFTOP"
	_dept_l.text = dept_name
	_dept_l.label_settings.font_color = col

func set_lives(n: int) -> void:
	for c in _lives.get_children():
		c.queue_free()
	for i in Cfg.START_LIVES:
		var r := TextureRect.new()
		r.texture = Art.tex("life")
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(84, 84)
		r.modulate = Color.WHITE if i < n else Color(0, 0, 0, 0.35)
		_lives.add_child(r)

func lose_life_fx() -> void:
	var t := create_tween()
	t.tween_property(_lives, "modulate", Color(1, 0.3, 0.3), 0.08)
	t.tween_property(_lives, "modulate", Color.WHITE, 0.3)

func set_progress(p: float) -> void:
	_progress = clampf(p, 0.0, 1.0)
	_bar.queue_redraw()

func _draw_bar() -> void:
	var h := _bar.size.y
	var w := 26.0
	var x := 9.0
	_bar.draw_rect(Rect2(x - 5, -5, w + 10, h + 10), Color(0.07, 0.08, 0.18, 0.7))
	var seg := h / (Cfg.FLOORS + 1.0)
	for f in range(1, Cfg.FLOORS + 1):
		var y1 := h - seg * 0.5 - seg * f
		var c: Color = LevelData.dept(LevelData.dept_index_for_floor(f)).color
		c = c.darkened(0.12 * (f % 2))
		c.a = 0.9
		_bar.draw_rect(Rect2(x, y1, w, seg - 2), c)
	_bar.draw_rect(Rect2(x, h - seg * 0.5, w, seg * 0.5 - 2), Color("8a92a6"))
	_bar.draw_rect(Rect2(x, 0, w, seg * 0.5 - 4), Color("ffd34a"))
	_bar.draw_string(Art.font(), Vector2(x - 2, seg * 0.5 - 16), "$", HORIZONTAL_ALIGNMENT_CENTER, w + 4, 30, Color("6a4a10"))
	var py := h - _progress * h
	_bar.draw_circle(Vector2(x + w * 0.5, py), 22, Color.WHITE)
	_bar.draw_arc(Vector2(x + w * 0.5, py), 22, 0, TAU, 32, Color("1b1f3b"), 5.0, true)
	_bar.draw_circle(Vector2(x + w * 0.5, py), 9, Color("c8102e"))

func set_promo(t: float) -> void:
	_promo.text = "MANAGER  %d" % ceili(t) if t > 0.0 else ""

func hide_hint() -> void:
	if _hint.visible:
		var t := create_tween()
		t.tween_property(_hint, "modulate:a", 0.0, 0.4)
		t.tween_callback(func(): _hint.visible = false)

## Department welcome: slides down from the top, holds, fades. Sits under the HUD bar.
func banner(title: String, sub: String, col: Color) -> void:
	if _banner:
		_banner.queue_free()
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_CENTER_TOP)
	holder.offset_left = -410
	holder.offset_right = 410
	holder.offset_top = 250
	holder.offset_bottom = 460
	var plate := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.18, 0.72)
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(4)
	sb.border_color = col
	plate.add_theme_stylebox_override("panel", sb)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(plate)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var t1 := Art.label(title, 56, col, 16)
	t1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t1.custom_minimum_size = Vector2(800, 0)
	var t2 := Art.small_label("\"" + sub + "\"", 31, Color.WHITE, 9)
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t2.custom_minimum_size = Vector2(780, 0)
	box.add_child(t1)
	box.add_child(t2)
	holder.add_child(box)
	_root.add_child(holder)
	_banner = holder
	holder.modulate.a = 0.0
	var tw := holder.create_tween()
	tw.tween_property(holder, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(holder, "position:y", 250.0, 0.3).from(160.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4)
	tw.tween_property(holder, "modulate:a", 0.0, 0.5)
	tw.tween_callback(holder.queue_free)

func flash_text(text: String, col: Color, y := 520.0, size := 84) -> void:
	var l := Art.label(text, size, col, 18)
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -520
	l.offset_right = 520
	l.offset_top = y
	l.offset_bottom = y + 120
	l.pivot_offset = Vector2(520, 60)
	_root.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE * 1.25, 0.12).from(Vector2.ONE * 0.4).set_trans(Tween.TRANS_BACK)
	tw.tween_property(l, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.tween_callback(l.queue_free)
