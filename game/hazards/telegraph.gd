class_name Telegraph
extends Node2D
## Warning marks drawn on the building while a thrower winds up: dashed danger lanes for falling objects,
## a dashed line + edge arrow for objects flying across a row. Readability first: every hazard is announced.

var marks: Array = []   # {type:"lane"|"row", x|y, from_y, until, color}
var _t := 0.0

func lane(x: float, from_y: float, dur: float, col := Color(1, 0.2, 0.2)) -> void:
	marks.append({"type": "lane", "x": x, "from_y": from_y, "until": _t + dur, "color": col})

func row(y: float, dir: float, dur: float) -> void:
	marks.append({"type": "row", "y": y, "dir": dir, "until": _t + dur, "color": Color(1, 0.25, 0.2)})

func _process(delta: float) -> void:
	_t += delta
	marks = marks.filter(func(m): return m.until > _t)
	queue_redraw()

func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var bottom := cam.get_screen_center_position().y + 1400 if cam else 2000.0
	var pulse := 0.55 + 0.45 * absf(sin(_t * 10.0))
	for m in marks:
		var c: Color = m.color
		c.a = pulse
		if m.type == "lane":
			var y: float = m.from_y + 70
			while y < bottom:
				draw_line(Vector2(m.x, y), Vector2(m.x, y + 34), c, 10.0)
				y += 62
			# chevrons
			for i in 3:
				var cy: float = m.from_y + 120 + i * 40 + fmod(_t * 120.0, 40.0)
				draw_polyline(PackedVector2Array([Vector2(m.x - 26, cy), Vector2(m.x, cy + 20), Vector2(m.x + 26, cy)]), c, 8.0)
		else:
			var x := Cfg.FACADE_L - 40
			while x < Cfg.FACADE_R + 40:
				draw_line(Vector2(x, m.y), Vector2(x + 40, m.y), c, 10.0)
				x += 74
			var ax := Cfg.FACADE_L + 30 if m.dir > 0 else Cfg.FACADE_R - 30
			var d: float = m.dir
			draw_colored_polygon(PackedVector2Array([Vector2(ax + d * 56, m.y), Vector2(ax - d * 10, m.y - 44), Vector2(ax - d * 10, m.y + 44)]), c)
