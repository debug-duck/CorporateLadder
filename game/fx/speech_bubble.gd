class_name SpeechBubble
extends Node2D
## Comic speech bubble: white rounded panel, thick ink outline, little tail pointing at the speaker.

const INK := Color("1b1f3b")
var _panel: PanelContainer
var _tail_x := 0.0
var _w := 0.0

static func make(text: String, size := 34, max_w := 560.0) -> SpeechBubble:
	var b := SpeechBubble.new()
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(6)
	sb.border_color = INK
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 14
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	var l := Art.label(text, size, INK, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var w := minf(max_w, Art.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 10)
	l.custom_minimum_size = Vector2(w, 0)
	b._w = w + 52.0 + 16.0
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b._panel = p
	b.add_child(p)
	return b

## pos = the speaker's mouth; the bubble sits above it, clamped inside the play width.
func place(pos: Vector2) -> void:
	position = pos
	_panel.reset_size()
	var sz := _panel.get_combined_minimum_size()
	sz.x = maxf(sz.x, _w)
	var vw := get_viewport().get_visible_rect().size.x if get_viewport() else Cfg.W
	var left := 20.0
	if get_viewport() and get_viewport().get_camera_2d() and not (get_parent() is Control):
		left = 20.0 - (vw - Cfg.W) * 0.5
		vw = Cfg.W + (vw - Cfg.W) * 0.5
	var x := clampf(pos.x - sz.x * 0.5, left, vw - 20.0 - sz.x)
	_panel.position = Vector2(x - pos.x, -sz.y - 30)
	_tail_x = clampf(0.0, _panel.position.x + 40, _panel.position.x + sz.x - 40)
	queue_redraw()
	scale = Vector2.ONE * 0.3
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func expire(life: float) -> void:
	var t := create_tween()
	t.tween_interval(life)
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)

func _draw() -> void:
	var pts := PackedVector2Array([Vector2(_tail_x - 20, -36), Vector2(_tail_x + 20, -36), Vector2(_tail_x + 4, 0)])
	draw_colored_polygon(pts, Color.WHITE)
	draw_polyline(PackedVector2Array([Vector2(_tail_x - 20, -33), Vector2(_tail_x + 4, 0), Vector2(_tail_x + 20, -33)]), INK, 6.0)
