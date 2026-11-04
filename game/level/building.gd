class_name Building
extends Node2D
## CORPORATE HQ: the facade is drawn once in _draw (concrete wall, pilasters, cornice ledges, department signs,
## satire banners, lobby + street); windows are OfficeWindow nodes (Layer art) so they can open and host throwers.

const WALL := Color("cfd5df")
const WALL_DARK := Color("b4bdcc")
const PILLAR := Color("bcc5d3")
const LEDGE := Color("e9edf3")
const LINE := Color("262b42")

var windows: Array = []          # [floor][col] -> OfficeWindow (floor 0 = lobby has none)
var pigeons: Array[Sprite2D] = []
var badge_nodes: Dictionary = {}  # Vector2i(col,row) -> Node2D

func _ready() -> void:
	windows.resize(Cfg.FLOORS + 1)
	for f in range(1, Cfg.FLOORS + 1):
		var row: Array = []
		var d: String = LevelData.dept(LevelData.dept_index_for_floor(f)).id
		for c in Cfg.COLS:
			var w := OfficeWindow.new()
			add_child(w)
			w.setup(f, c, d, LevelData.blocker_kind(f, c))
			row.append(w)
		windows[f] = row
	_add_rooftop()
	_add_badges()
	_add_pigeons()
	_add_lobby_props()
	queue_redraw()

func window_at(f: int, c: int) -> OfficeWindow:
	if f < 1 or f > Cfg.FLOORS:
		return null
	return windows[f][c]

func _add_rooftop() -> void:
	var s := Sprite2D.new()
	s.texture = Art.tex("rooftop")
	if s.texture == null:
		return
	var sc := (Cfg.FACADE_R - Cfg.FACADE_L + 40) / s.texture.get_width()
	s.scale = Vector2.ONE * sc
	s.position = Vector2(Cfg.CENTER_X, Cfg.floor_base_y(Cfg.FLOORS + 1) + 26 - s.texture.get_height() * sc * 0.5)
	add_child(s)
	# billboard text on the blank panel
	var l := Art.label("CEO", 64, Color("c8102e"), 10, Color("ffffff"))
	l.size = Vector2(240, 80)
	l.position = s.position + Vector2(-120 + 10, -s.texture.get_height() * sc * 0.5 + 34)
	add_child(l)

func _add_badges() -> void:
	for b in LevelData.BADGES:
		var n := Node2D.new()
		n.position = Cfg.cell_pos(int(b[0]), int(b[1])) + Vector2(0, 40)
		var glow := Sprite2D.new()
		glow.texture = _glow_tex()
		glow.modulate = Color(1, 0.9, 0.3, 0.75)
		glow.scale = Vector2.ONE * 2.6
		n.add_child(glow)
		var s := Sprite2D.new()
		s.texture = Art.tex("badge")
		s.scale = Vector2.ONE * 0.5
		n.add_child(s)
		add_child(n)
		badge_nodes[Vector2i(int(b[0]), int(b[1]))] = n
		var t := n.create_tween().set_loops()
		t.tween_property(s, "scale", Vector2.ONE * 0.56, 0.45).set_trans(Tween.TRANS_SINE)
		t.tween_property(s, "scale", Vector2.ONE * 0.5, 0.45).set_trans(Tween.TRANS_SINE)

func take_badge(cell: Vector2i) -> bool:
	if not badge_nodes.has(cell):
		return false
	var n: Node2D = badge_nodes[cell]
	badge_nodes.erase(cell)
	var t := n.create_tween()
	t.tween_property(n, "scale", Vector2.ONE * 1.8, 0.2)
	t.parallel().tween_property(n, "modulate:a", 0.0, 0.25)
	t.tween_callback(n.queue_free)
	return true

static var _glow: Texture2D
static func _glow_tex() -> Texture2D:
	if _glow == null:
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		g.width = 64
		g.height = 64
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		g.gradient = gr
		_glow = g
	return _glow

func glow_texture() -> Texture2D:
	return _glow_tex()

func _add_pigeons() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for f in [1, 3, 4, 7, 9, 10, 13, 15]:
		var p := Sprite2D.new()
		p.texture = Art.tex("pigeon")
		p.scale = Vector2(0.3, 0.3)
		var c := rng.randi_range(0, Cfg.COLS - 2)
		p.position = Vector2(Cfg.col_x(c) + 90, Cfg.floor_base_y(f) - 30)
		if rng.randf() < 0.5:
			p.flip_h = true
		add_child(p)
		pigeons.append(p)

## Pigeons flap away when the climber gets close (pure comedy).
func scare_pigeons(near: Vector2) -> void:
	for p in pigeons:
		if not is_instance_valid(p) or p.get_meta("gone", false):
			continue
		if p.position.distance_to(near) < 170:
			p.set_meta("gone", true)
			Sfx.play("coo", -4.0)
			var dir := -1.0 if p.position.x < near.x else 1.0
			p.flip_h = dir < 0
			var t := p.create_tween()
			t.tween_property(p, "position", p.position + Vector2(dir * 700, -420), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(p, "rotation", dir * 0.4, 0.3)
			t.tween_callback(p.queue_free)

func _add_lobby_props() -> void:
	for x in [Cfg.col_x(1) - 10, Cfg.col_x(3) + 10]:
		var f := Sprite2D.new()
		f.texture = Art.tex("ficus")
		f.scale = Vector2.ONE * 0.85
		f.position = Vector2(x, Cfg.STREET_Y - 80)
		add_child(f)

# ---------------------------------------------------------------- drawing
func _draw() -> void:
	var top := Cfg.floor_base_y(Cfg.FLOORS + 1)
	var l := Cfg.FACADE_L
	var r := Cfg.FACADE_R
	# street + sidewalk
	draw_rect(Rect2(-1200, Cfg.STREET_Y, 3480, 2000), Color("4a4f63"))
	draw_rect(Rect2(-1200, Cfg.STREET_Y, 3480, 150), Color("b9bdc8"))
	draw_rect(Rect2(-1200, Cfg.STREET_Y + 150, 3480, 18), Color("8d92a1"))
	for i in 20:
		draw_rect(Rect2(-1100 + i * 220, Cfg.STREET_Y + 330, 120, 16), Color("f2d24b"))
	for i in 30:
		draw_line(Vector2(-1200 + i * 130, Cfg.STREET_Y), Vector2(-1200 + i * 130 + 20, Cfg.STREET_Y + 150), Color("a7abb7"), 3)
	# building body
	draw_rect(Rect2(l, top, r - l, Cfg.STREET_Y - top), WALL)
	for f in range(0, Cfg.FLOORS + 1):
		var base := Cfg.floor_base_y(f)
		draw_rect(Rect2(l, base - Cfg.FLOOR_H, r - l, 60), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(l, base - 70, r - l, 70), Color(0, 0, 0, 0.05))
	# pilasters between columns
	for c in Cfg.COLS + 1:
		var x := Cfg.col_x(c) - Cfg.COL_W * 0.5
		var w := 26.0 if c > 0 and c < Cfg.COLS else 34.0
		var px := clampf(x - w * 0.5, l, r - w)
		draw_rect(Rect2(px, top, w, Cfg.STREET_Y - top), PILLAR)
		draw_rect(Rect2(px, top, 6, Cfg.STREET_Y - top), Color(1, 1, 1, 0.35))
		draw_line(Vector2(px + w, top), Vector2(px + w, Cfg.STREET_Y), Color(0, 0, 0, 0.18), 3)
	# lobby (floor 0)
	_draw_lobby()
	# cornice ledges, department trim, signs, banners
	for f in range(1, Cfg.FLOORS + 2):
		var base := Cfg.floor_base_y(f)
		var di := LevelData.dept_index_for_floor(f)
		var d := LevelData.dept(di)
		draw_rect(Rect2(l - 14, base - 14, r - l + 28, 34), LEDGE)
		draw_rect(Rect2(l - 14, base + 14, r - l + 28, 8), d.color.darkened(0.1) if f <= Cfg.FLOORS else Color("d9b44a"))
		draw_rect(Rect2(l - 14, base + 22, r - l + 28, 14), Color(0, 0, 0, 0.16))
		draw_rect(Rect2(l - 14, base - 14, r - l + 28, 36), LINE, false, 4.0)
		if f <= Cfg.FLOORS and LevelData.floor_in_dept(f) == 1:
			# department sign right above the ledge where you enter the department
			_sign(Vector2(Cfg.CENTER_X, base - 56), d.name, d.color, 42)
		if LevelData.BANNERS.has(f):
			_banner(Vector2(Cfg.CENTER_X, base - 352), LevelData.BANNERS[f])
	# outline of the tower
	draw_rect(Rect2(l, top, r - l, Cfg.STREET_Y - top), LINE, false, 6.0)

func _draw_lobby() -> void:
	var y0 := Cfg.floor_base_y(1) + 36
	var y1 := Cfg.STREET_Y
	var glass := Rect2(Cfg.FACADE_L + 30, y0 + 70, Cfg.FACADE_R - Cfg.FACADE_L - 60, y1 - y0 - 70)
	draw_rect(glass, Color("2b3d5c"))
	for i in 6:
		var x := glass.position.x + i * glass.size.x / 6.0
		draw_line(Vector2(x, glass.position.y), Vector2(x, y1), Color("9aa8bf"), 8)
		draw_colored_polygon(PackedVector2Array([Vector2(x + 30, glass.position.y), Vector2(x + 80, glass.position.y),
			Vector2(x + 10, glass.position.y + 160), Vector2(x - 40, glass.position.y + 160)]), Color(1, 1, 1, 0.08))
	draw_line(Vector2(glass.position.x, glass.position.y + 120), Vector2(glass.end.x, glass.position.y + 120), Color("9aa8bf"), 6)
	draw_rect(glass, LINE, false, 6.0)
	# revolving door
	var door := Rect2(Cfg.CENTER_X - 100, y1 - 260, 200, 260)
	draw_rect(door, Color("1d2a40"))
	draw_rect(Rect2(door.position.x + 10, door.position.y + 10, 85, 250), Color(0.6, 0.75, 0.95, 0.35))
	draw_rect(Rect2(door.position.x + 105, door.position.y + 10, 85, 250), Color(0.6, 0.75, 0.95, 0.25))
	draw_rect(door, Color("c9a23a"), false, 8.0)
	draw_rect(Rect2(Cfg.CENTER_X - 150, y1 - 300, 300, 40), Color("8c1b2a"))
	draw_rect(Rect2(Cfg.CENTER_X - 150, y1 - 300, 300, 40), LINE, false, 4.0)
	_sign(Vector2(Cfg.CENTER_X, y0 + 18), "CORPORATE HQ", Color("ffd34a"), 58)

func _sign(c: Vector2, text: String, col: Color, size: int) -> void:
	var f := Art.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 70
	var rect := Rect2(c.x - w * 0.5, c.y - size * 0.75, w, size * 1.5)
	draw_rect(Rect2(rect.position + Vector2(6, 8), rect.size), Color(0, 0, 0, 0.25))
	draw_rect(rect, col)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 10)), Color(1, 1, 1, 0.3))
	draw_rect(rect, LINE, false, 6.0)
	for x in [rect.position.x + 14, rect.end.x - 14]:
		draw_circle(Vector2(x, c.y), 6, LINE)
	var base := Vector2(rect.position.x, c.y + size * 0.36)
	draw_string_outline(f, base, text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, 12, LINE)
	draw_string(f, base, text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, Color.WHITE)

func _banner(c: Vector2, text: String) -> void:
	var f := Art.font()
	var size := 34
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 80
	var rect := Rect2(c.x - w * 0.5, c.y - 30, w, 60)
	var pts := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - 18, c.y),
		Vector2(rect.end.x, rect.end.y), Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + 18, c.y)])
	draw_colored_polygon(pts, Color("fff4d6"))
	pts.append(rect.position)
	draw_polyline(pts, LINE, 4.0)
	draw_line(Vector2(rect.position.x + 20, rect.position.y - 26), rect.position + Vector2(20, 0), LINE, 3)
	draw_line(Vector2(rect.end.x - 20, rect.position.y - 26), Vector2(rect.end.x - 20, rect.position.y), LINE, 3)
	draw_string(f, Vector2(rect.position.x, c.y + 13), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, Color("c8102e"))
