class_name Victory
extends CanvasLayer
## The CEO ending: the exhausted employee climbs in through the penthouse window, demands a raise,
## gets a meaningless title instead. Short (~7 s) and skippable with a tap / key.

signal finished

var _root: Control
var _ceo: TextureRect
var _hero: TextureRect
var _done := false
var _tw: Tween

func _ready() -> void:
	layer = 15
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := TextureRect.new()
	bg.texture = Art.tex("bg_penthouse")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_root.add_child(bg)
	var vs := get_viewport().get_visible_rect().size
	var c := vs * 0.5
	_ceo = _sprite("ceo_sit", Vector2(720, 580))
	_ceo.position = c + Vector2(-360 + 110, -250)
	_hero = _sprite("climb_a", Vector2(320, 380))
	_hero.position = Vector2(-340, c.y + 120)
	var hero_x := c.x - 470
	var flash := ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(flash)
	var skip := Art.small_label("TAP TO SKIP", 30, Color(1, 1, 1, 0.8), 7)
	skip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skip.position = Vector2(-200, -90)
	skip.size = Vector2(400, 50)
	_root.add_child(skip)
	Sfx.play("victory", 0.0)
	_tw = create_tween()
	_tw.tween_property(flash, "modulate:a", 0.0, 0.5)
	_tw.tween_property(_hero, "position:x", hero_x, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_callback(func(): _pose(_hero, "victory"))
	_tw.tween_callback(func(): _say(Vector2(hero_x + 160, c.y + 130), "I WANT A RAISE!"))
	_tw.tween_interval(1.7)
	_tw.tween_callback(func():
		_pose(_ceo, "ceo_cheer")
		Sfx.play("promote", 0.0)
		_say(Vector2(c.x + 110, c.y - 250), "Congratulations! You're now SENIOR JUNIOR ASSOCIATE!", 600.0)
		_confetti())
	_tw.tween_interval(1.2)
	_tw.tween_callback(func(): _pose(_hero, "hit"))
	_tw.tween_interval(2.3)
	_tw.tween_callback(_finish)

func _sprite(n: String, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Art.tex(n)
	t.custom_minimum_size = sz
	t.size = sz
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.pivot_offset = sz * 0.5
	_root.add_child(t)
	return t

func _pose(t: TextureRect, n: String) -> void:
	t.texture = Art.tex(n)
	var tw := t.create_tween()
	tw.tween_property(t, "scale", Vector2.ONE * 1.12, 0.08)
	tw.tween_property(t, "scale", Vector2.ONE, 0.12)

var _bubbles: Array = []

func _say(at: Vector2, text: String, w := 520.0) -> void:
	var b := SpeechBubble.make(text, 42, w)
	_root.add_child(b)
	b.place(at)
	_bubbles.append(b)

func _confetti() -> void:
	var vs := get_viewport().get_visible_rect().size
	var p := CPUParticles2D.new()
	p.amount = 140
	p.lifetime = 3.0
	p.one_shot = true
	p.explosiveness = 0.7
	p.position = Vector2(vs.x * 0.5, -40)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(vs.x * 0.5, 10)
	p.direction = Vector2(0, 1)
	p.spread = 30
	p.initial_velocity_min = 100
	p.initial_velocity_max = 380
	p.gravity = Vector2(0, 420)
	p.scale_amount_min = 10
	p.scale_amount_max = 18
	p.angular_velocity_min = -300
	p.angular_velocity_max = 300
	p.hue_variation_min = -1.0
	p.hue_variation_max = 1.0
	p.color = Color("ff5aa5")
	_root.add_child(p)
	p.emitting = true

func _input(event: InputEvent) -> void:
	if _done:
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed and not event.echo):
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	if _tw and _tw.is_valid():
		_tw.kill()
	_pose(_hero, "victory")
	for b in _bubbles:
		if is_instance_valid(b):
			b.queue_free()
	finished.emit()
