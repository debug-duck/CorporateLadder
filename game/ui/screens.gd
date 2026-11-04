class_name Screens
extends RefCounted
## Builders for the full-screen overlays: title, pause ("COFFEE BREAK"), game over, results.
## Each returns a Control that runs while the tree is paused (PROCESS_MODE_ALWAYS).

const INK := Color("1b1f3b")

static func button(text: String, cb: Callable, col := Color("ffd34a"), w := 560.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 128)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Art.font())
	b.add_theme_font_size_override("font_size", 64)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col if st != "pressed" else col.darkened(0.2)
		if st == "hover":
			sb.bg_color = col.lightened(0.12)
		sb.set_corner_radius_all(30)
		sb.set_border_width_all(8)
		sb.border_color = INK
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 0
		sb.shadow_offset = Vector2(0, 10)
		sb.content_margin_top = 14
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func():
		Sfx.play("click", -4.0)
		cb.call())
	return b

static func _root() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	return c

static func _dim(parent: Control, a := 0.62) -> void:
	var d := ColorRect.new()
	d.color = Color(0.05, 0.05, 0.14, a)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(d)

static func _column(parent: Control, sep := 26) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", sep)
	parent.add_child(v)
	return v

static func _centered(node: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.add_child(node)
	return cc

static func _text(v: Control, text: String, size: int, col := Color.WHITE, small := false, width := 980.0) -> Label:
	var l := Art.small_label(text, size, col, 9) if small else Art.label(text, size, col, 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	v.add_child(_centered(l))
	return l

static func title(hi: int, best_floor: int, on_play: Callable) -> Control:
	var r := _root()
	var bg := TextureRect.new()
	bg.texture = Art.tex("bg_sky")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.add_child(bg)
	var v := _column(r, 20)
	var logo := TextureRect.new()
	logo.texture = Art.tex("logo")
	logo.custom_minimum_size = Vector2(980, 560)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(_centered(logo))
	_text(v, "SEVEN YEARS. NO RAISE.\nTHE CEO IS ON THE TOP FLOOR.\nTHE ELEVATOR IS FOR EXECUTIVES.", 40, INK, true)
	var hero := TextureRect.new()
	hero.texture = Art.tex("hang")
	hero.custom_minimum_size = Vector2(300, 330)
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(_centered(hero))
	var b := button("CLIMB!", on_play, Color("ffd34a"), 620)
	v.add_child(_centered(b))
	b.pivot_offset = Vector2(310, 64)
	var tw := b.create_tween().set_loops()
	tw.tween_property(b, "scale", Vector2.ONE * 1.06, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	if hi > 0:
		_text(v, "HIGH SCORE  %s   ·   BEST FLOOR %d" % [Hud._fmt(hi), best_floor], 36, Color.WHITE, true)
	var cr := Art.small_label("A WRONG BUTTON GAMES PROTOTYPE", 26, Color(1, 1, 1, 0.8), 6)
	cr.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cr.position = Vector2(-400, -70)
	cr.size = Vector2(800, 40)
	r.add_child(cr)
	return r

static func pause_menu(on_resume: Callable, on_restart: Callable, on_title: Callable) -> Control:
	var r := _root()
	_dim(r)
	var v := _column(r, 34)
	_text(v, "COFFEE BREAK", 110, Color("ffd34a"))
	_text(v, "(UNPAID)", 40, Color.WHITE, true)
	v.add_child(_centered(button("RESUME", on_resume)))
	v.add_child(_centered(button("RESTART", on_restart, Color("ff8a5c"))))
	v.add_child(_centered(button("QUIT", on_title, Color("b9c3d6"))))
	return r

const FIRED_LINES := ["PLEASE RETURN YOUR STAPLER ON THE WAY DOWN.", "HR HAS BEEN NOTIFIED. HR DOES NOT CARE.",
	"YOUR DESK PLANT HAS BEEN REASSIGNED.", "THIS WILL BE REFLECTED IN YOUR PERFORMANCE REVIEW.",
	"WE WISH YOU THE BEST IN YOUR FUTURE ENDEAVOURS.", "EXIT INTERVIEW: ALREADY HAPPENING."]

static func game_over(score: int, floor_reached: int, record: bool, hi: int, on_reapply: Callable, on_title: Callable) -> Control:
	var r := _root()
	_dim(r, 0.72)
	var v := _column(r, 22)
	_text(v, "YOUR POSITION HAS BEEN TERMINATED.", 92, Color("ff5a5a"))
	_text(v, FIRED_LINES.pick_random(), 38, Color.WHITE, true, 900)
	v.add_child(_spacer(20))
	_text(v, "SCORE  " + Hud._fmt(score), 72, Color("ffe14d"))
	_text(v, "REACHED FLOOR %d OF %d" % [floor_reached, Cfg.FLOORS], 38, Color.WHITE, true)
	if record:
		_text(v, "NEW HIGH SCORE!", 56, Color("5ed37a"))
	else:
		_text(v, "HIGH SCORE  " + Hud._fmt(hi), 36, Color(1, 1, 1, 0.8), true)
	v.add_child(_spacer(30))
	v.add_child(_centered(button("REAPPLY", on_reapply, Color("ffd34a"), 620)))
	v.add_child(_centered(button("QUIT", on_title, Color("b9c3d6"), 420)))
	return r

static func results(score: int, lines: Array, record: bool, on_again: Callable, on_title: Callable) -> Control:
	var r := _root()
	_dim(r, 0.55)
	var v := _column(r, 16)
	_text(v, "PERFORMANCE REVIEW", 60, Color.WHITE)
	_text(v, "SALARY INCREASE: 0%", 74, Color("ff8a5c"))
	_text(v, "RESPONSIBILITIES: +200%", 74, Color("5ed37a"))
	_text(v, "\"CONGRATULATIONS!\"", 66, Color("ffd34a"))
	v.add_child(_spacer(14))
	for l in lines:
		_text(v, l, 36, Color.WHITE, true)
	_text(v, "FINAL SCORE  " + Hud._fmt(score), 80, Color("ffe14d"))
	if record:
		_text(v, "NEW HIGH SCORE!", 54, Color("5ed37a"))
	v.add_child(_spacer(16))
	v.add_child(_centered(button("PLAY AGAIN", on_again, Color("ffd34a"), 640)))
	v.add_child(_centered(button("QUIT", on_title, Color("b9c3d6"), 420)))
	return r

static func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
