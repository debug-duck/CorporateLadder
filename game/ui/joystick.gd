class_name Joystick
extends Control
## Floating one-thumb joystick: touch anywhere below the HUD bar, drag in a direction.
## 4-way output with a deadzone and a slight bias toward vertical (climbing is the main action).
## Works with the mouse on desktop (touch is emulated from the mouse).

signal dir_changed(dir: Vector2i)

const DEADZONE := 30.0
const RADIUS := 120.0
const TOP_RESERVED := 190.0

var dir := Vector2i.ZERO
var active := false
var enabled := true
var _touch := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _hint_t := 0.0
var show_hint := true

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if not enabled or get_tree().paused:
		if active:
			_release()
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1 and event.position.y > TOP_RESERVED:
			_touch = event.index
			_origin = event.position
			_knob = event.position
			active = true
			show_hint = false
			queue_redraw()
		elif not event.pressed and event.index == _touch:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch:
		var v: Vector2 = event.position - _origin
		if v.length() > RADIUS:
			# drag the base along so reversing direction is instant
			_origin = event.position - v.normalized() * RADIUS
			v = event.position - _origin
		_knob = _origin + v
		var nd := Vector2i.ZERO
		if v.length() > DEADZONE:
			if absf(v.y) >= absf(v.x) * 0.75:
				nd = Vector2i(0, 1 if v.y > 0 else -1)
			else:
				nd = Vector2i(1 if v.x > 0 else -1, 0)
		_set_dir(nd)
		queue_redraw()

func _release() -> void:
	_touch = -1
	active = false
	_set_dir(Vector2i.ZERO)
	queue_redraw()

func _set_dir(d: Vector2i) -> void:
	if d != dir:
		dir = d
		dir_changed.emit(d)

func _process(delta: float) -> void:
	if show_hint:
		_hint_t += delta
		queue_redraw()

func _draw() -> void:
	if active:
		draw_circle(_origin, RADIUS + 14, Color(0.1, 0.12, 0.25, 0.28))
		draw_arc(_origin, RADIUS + 14, 0, TAU, 48, Color(1, 1, 1, 0.55), 6.0, true)
		for i in 4:
			var a := i * PI * 0.5
			var p := _origin + Vector2.from_angle(a) * (RADIUS - 18)
			var lit := Vector2(dir) == Vector2.from_angle(a).round()
			var c := Color(1, 0.85, 0.2, 0.95) if lit else Color(1, 1, 1, 0.4)
			var fwd := Vector2.from_angle(a)
			var side := fwd.orthogonal()
			draw_colored_polygon(PackedVector2Array([p + fwd * 22, p - fwd * 10 + side * 22, p - fwd * 10 - side * 22]), c)
		draw_circle(_knob, 54, Color(1, 1, 1, 0.85))
		draw_arc(_knob, 54, 0, TAU, 40, Color("1b1f3b"), 6.0, true)
	elif show_hint:
		var vs := get_viewport_rect().size
		var c := Vector2(vs.x * 0.5, vs.y - 300)
		var off := Vector2(0, -sin(_hint_t * 3.0) * 60)
		draw_arc(c, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.45), 6.0, true)
		draw_circle(c + off, 46, Color(1, 1, 1, 0.6))
