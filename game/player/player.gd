class_name Player
extends Node2D
## The climber. Grid movement (col,row) with short arcade tweens; holding a direction repeats moves.
## position = grip point (hands); the hit circle is BODY_OFFSET below it.
## Manager mode swaps the sprites (suit, sunglasses, giant gold tie) and adds the intern shield.

signal moved(col: int, row: int)
signal blocked_bump
signal reached_top
signal fell_off

enum State { IDLE, MOVING, STUNNED, FALLING, VICTORY }

var col := 2
var row := 0
var state := State.IDLE
var held_dir := Vector2i.ZERO
var invuln := 0.0
var manager_time := 0.0
var has_intern := false
var frozen := false

var _sprite: Sprite2D
var _intern: Sprite2D
var _climb_flip := false
var _idle_t := 0.0
var _bob := 0.0
var _move_tw: Tween

func _ready() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_intern = Sprite2D.new()
	_intern.texture = Art.tex("intern")
	_intern.visible = false
	add_child(_intern)
	_set_pose("hang")
	position = Cfg.cell_pos(col, row)

func is_manager() -> bool:
	return manager_time > 0.0

func body_pos() -> Vector2:
	return global_position + Cfg.BODY_OFFSET

func cell() -> Vector2i:
	return Vector2i(col, row)

func _set_pose(p: String) -> void:
	var n := p
	if is_manager():
		n = {"hang": "mgr_hang", "climb_a": "mgr_climb", "climb_b": "mgr_climb", "side": "mgr_climb"}.get(p, p)
	var t := Art.tex(n)
	if t == null:
		return
	_sprite.texture = t
	var target_h := 212.0 if not (p in ["hit", "fall", "side"]) else 190.0
	var s := target_h / t.get_height()
	if p == "side":
		s = 165.0 / t.get_height()
	_sprite.scale = Vector2(s, s)
	# hands at the grip point: hanging sprites are top-anchored, others centred on the body
	if p in ["hit", "fall", "victory", "side"]:
		_sprite.offset = Vector2.ZERO
		_sprite.position = Cfg.BODY_OFFSET + Vector2(0, -10)
	else:
		_sprite.offset = Vector2(0, t.get_height() * 0.5)
		_sprite.position = Vector2(0, -14)

func _process(delta: float) -> void:
	if invuln > 0.0:
		invuln -= delta
		_sprite.modulate.a = 0.35 if fmod(invuln, 0.16) < 0.08 else 1.0
	else:
		_sprite.modulate.a = 1.0
	if manager_time > 0.0:
		manager_time -= delta
		if manager_time <= 0.0:
			_end_promotion()
	if has_intern:
		_bob += delta
		_intern.position = Vector2(-96 if col > 0 else 96, 120 + sin(_bob * 3.0) * 8)
		_intern.flip_h = col == 0
		_intern.rotation = sin(_bob * 2.0) * 0.12
	if state == State.IDLE:
		_idle_t += delta
		_sprite.rotation = sin(_idle_t * 2.4) * 0.03
		if held_dir != Vector2i.ZERO and not frozen:
			try_move(held_dir)
		elif _idle_t > 0.14 and _sprite.texture != Art.tex("mgr_hang" if is_manager() else "hang"):
			_set_pose("hang")

## dir: (1,0) right, (-1,0) left, (0,-1) up, (0,1) down
func try_move(dir: Vector2i) -> void:
	if state != State.IDLE or frozen:
		return
	var nc := col + dir.x
	var nr := row - dir.y
	if nr >= Cfg.TOP_ROW:
		_climb_to_roof()
		return
	if nc < 0 or nc >= Cfg.COLS or nr < 0 or LevelData.is_blocked(nc, nr):
		_bump(dir)
		return
	col = nc
	row = nr
	state = State.MOVING
	var dur := Cfg.MOVE_UP_TIME if dir.y < 0 else (Cfg.MOVE_DOWN_TIME if dir.y > 0 else Cfg.MOVE_SIDE_TIME)
	if dir.y != 0:
		_climb_flip = not _climb_flip
		_set_pose("climb_a" if _climb_flip else "climb_b")
		_sprite.flip_h = is_manager() and _climb_flip
		Sfx.play("climb", -8.0, 0.15)
	else:
		_set_pose("side")
		_sprite.flip_h = dir.x < 0
		Sfx.play("shimmy", -9.0, 0.12)
	_sprite.rotation = 0.0
	_move_tw = create_tween()
	_move_tw.tween_property(self, "position", Cfg.cell_pos(col, row), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var sq := _sprite.scale
	var t2 := create_tween()
	t2.tween_property(_sprite, "scale", Vector2(sq.x * 0.94, sq.y * 1.07), dur * 0.5)
	t2.tween_property(_sprite, "scale", sq, dur * 0.5)
	_move_tw.tween_callback(_arrive)

func _arrive() -> void:
	if state != State.MOVING:
		return
	state = State.IDLE
	_idle_t = 0.0
	if held_dir == Vector2i.ZERO:
		_sprite.flip_h = false
	moved.emit(col, row)

func _bump(dir: Vector2i) -> void:
	blocked_bump.emit()
	state = State.MOVING
	var p := position
	var t := create_tween()
	t.tween_property(self, "position", p + Vector2(dir.x * 18, dir.y * 18), 0.06)
	t.tween_property(self, "position", p, 0.08)
	t.tween_callback(func():
		if state == State.MOVING:
			state = State.IDLE
			_idle_t = 0.0)

func _climb_to_roof() -> void:
	state = State.VICTORY
	row = Cfg.TOP_ROW
	_set_pose("climb_a")
	var t := create_tween()
	t.tween_property(self, "position", Cfg.cell_pos(col, Cfg.TOP_ROW), 0.3)
	t.tween_callback(func(): _set_pose("victory"))
	t.tween_interval(0.25)
	t.tween_callback(func(): reached_top.emit())

func promote() -> void:
	manager_time = Cfg.PROMO_TIME
	has_intern = true
	_intern.visible = true
	_intern.scale = Vector2.ONE * 0.4
	_intern.modulate.a = 1.0
	_set_pose("hang")
	var s := _sprite.scale
	var t := create_tween()
	t.tween_property(_sprite, "scale", s * 1.35, 0.12)
	t.tween_property(_sprite, "scale", s, 0.18).set_trans(Tween.TRANS_BACK)

func _end_promotion() -> void:
	manager_time = 0.0
	if has_intern:
		has_intern = false
		var t := create_tween()
		t.tween_property(_intern, "modulate:a", 0.0, 0.3)
		t.tween_callback(func(): _intern.visible = false)
	if state == State.IDLE or state == State.MOVING:
		_set_pose("hang")

## Intern takes the hit: returns the intern's world position for the launch gag.
func spend_intern() -> Vector2:
	has_intern = false
	_intern.visible = false
	invuln = 0.8
	return _intern.global_position

func stun() -> void:
	if _move_tw and _move_tw.is_valid():
		_move_tw.kill()
	position = Cfg.cell_pos(col, row)
	state = State.STUNNED
	invuln = Cfg.INVULN_TIME
	_set_pose("hit")
	var t := create_tween()
	t.tween_property(_sprite, "rotation", 0.25, 0.06)
	t.tween_property(_sprite, "rotation", -0.2, 0.08)
	t.tween_property(_sprite, "rotation", 0.0, 0.08)
	t.tween_interval(Cfg.STUN_TIME - 0.22)
	t.tween_callback(func():
		if state == State.STUNNED:
			state = State.IDLE
			_idle_t = 0.0
			_set_pose("hang"))

func fall() -> void:
	if _move_tw and _move_tw.is_valid():
		_move_tw.kill()
	state = State.FALLING
	has_intern = false
	_intern.visible = false
	manager_time = 0.0
	_set_pose("fall")
	_sprite.modulate.a = 1.0
	invuln = 0.0
	var t := create_tween()
	t.tween_property(self, "position", position + Vector2(0, -60), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", position + Vector2(randf_range(-80, 80), 1500), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_sprite, "rotation", TAU * 1.5, 1.1)
	t.tween_callback(func(): fell_off.emit())
