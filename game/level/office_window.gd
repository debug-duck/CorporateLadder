class_name OfficeWindow
extends Node2D
## One office window on the facade. Throwers use it as a little stage:
## window opens -> worker pops up holding the item overhead + "!" (the warning) -> throw pose
## releases the projectile -> smug pause (maybe a catchphrase) -> worker ducks, window closes.
## Ambient "peekers" only lean out and never raise their arms, so a raised item always means danger.

signal released(win: OfficeWindow)

const WIN_SCALE := 0.68
const SILL_FRAC := 0.17

var floor_i := 0
var col := 0
var dept_id := "hr"
var blocker := ""                # "", boarded, ac, ficus
var busy := false
var item := ""

var _frame: Sprite2D
var _worker: Sprite2D
var _sill: Sprite2D
var _held: Sprite2D
var _alert: Label
var _prop: Sprite2D
var _t := 0.0
var _phase := ""

func setup(f: int, c: int, d: String, block: String) -> void:
	floor_i = f
	col = c
	dept_id = d
	blocker = block
	position = Cfg.window_pos(f, c)
	_frame = Sprite2D.new()
	_frame.scale = Vector2.ONE * WIN_SCALE
	add_child(_frame)
	_worker = Sprite2D.new()
	_worker.visible = false
	add_child(_worker)
	_held = Sprite2D.new()
	_held.visible = false
	add_child(_held)
	_sill = Sprite2D.new()
	_sill.scale = Vector2.ONE * WIN_SCALE
	_sill.region_enabled = true
	add_child(_sill)
	_alert = Art.label("!", 84, Color("ff3b3b"), 16)
	_alert.size = Vector2(80, 100)
	_alert.position = Vector2(-40, -230)
	_alert.visible = false
	add_child(_alert)
	if block == "boarded":
		_frame.texture = Art.tex("win_boarded")
	else:
		_set_open(false)
	if block == "ac" or block == "ficus":
		_prop = Sprite2D.new()
		_prop.texture = Art.tex("ac_unit" if block == "ac" else "ficus")
		_prop.scale = Vector2.ONE * (0.78 if block == "ac" else 0.82)
		_prop.position = Vector2(0, 30 if block == "ac" else 6)
		add_child(_prop)
	_update_sill()

func can_act() -> bool:
	return blocker == "" and not busy

func _set_open(open: bool) -> void:
	_frame.texture = Art.tex(("open_" if open else "win_") + dept_id)
	_update_sill()

func _update_sill() -> void:
	var t := _frame.texture
	_sill.visible = t != null and blocker != "boarded" and _frame.texture != Art.tex("win_" + dept_id)
	if t == null:
		return
	var sh := t.get_height() * SILL_FRAC
	_sill.texture = t
	_sill.region_rect = Rect2(0, t.get_height() - sh, t.get_width(), sh)
	_sill.position = Vector2(0, (t.get_height() * 0.5 - sh * 0.5) * WIN_SCALE)

func sill_y() -> float:
	var t := _frame.texture
	return (t.get_height() * (0.5 - SILL_FRAC)) * WIN_SCALE if t else 70.0

## The point (world) where the thrown item leaves the worker's hands.
func release_point() -> Vector2:
	return global_position + Vector2(0, -40)

func _show_worker(pose: String) -> void:
	var tx := Art.tex("%s_%s" % [dept_id, pose])
	_worker.texture = tx
	_worker.visible = tx != null
	if tx:
		var s := 172.0 / tx.get_height()
		_worker.scale = Vector2.ONE * s
		_worker.position = Vector2(0, sill_y() + 6 - tx.get_height() * s * 0.5)

## Ambient: a worker leans out and looks smug (no danger).
func peek(dur := 1.6) -> void:
	if not can_act():
		return
	busy = true
	_set_open(true)
	_show_worker("idle")
	_pop(_worker)
	await get_tree().create_timer(dur, false).timeout
	if is_instance_valid(self):
		_close()

## Full throw sequence. `warn` = seconds between the item being raised and the release.
func throw_item(item_name: String, warn: float) -> void:
	busy = true
	item = item_name
	_set_open(true)
	Sfx.play("window", -6.0)
	_pop(_frame, 1.06)
	await get_tree().create_timer(0.18, false).timeout
	if not is_instance_valid(self):
		return
	_show_worker("ready")
	_pop(_worker)
	_held.texture = Art.tex(item_name)
	_held.scale = Vector2.ONE * 0.36
	_held.position = _worker.position + Vector2(0, -_worker.texture.get_height() * _worker.scale.y * 0.5 - 10) if _worker.texture else Vector2(0, -150)
	_held.visible = true
	_alert.visible = true
	_phase = "ready"
	_t = 0.0
	await get_tree().create_timer(warn, false).timeout
	if not is_instance_valid(self):
		return
	_phase = ""
	_alert.visible = false
	_held.visible = false
	_show_worker("throw")
	Sfx.play("throw", -3.0)
	released.emit(self)
	await get_tree().create_timer(0.55, false).timeout
	if not is_instance_valid(self):
		return
	_show_worker("idle")
	await get_tree().create_timer(0.45, false).timeout
	if is_instance_valid(self):
		_close()

func _close() -> void:
	var t := create_tween()
	t.tween_property(_worker, "position:y", _worker.position.y + 60, 0.12)
	t.tween_callback(func():
		_worker.visible = false
		_set_open(false)
		busy = false)

func _pop(n: Node2D, amt := 1.12) -> void:
	var s := n.scale
	var t := create_tween()
	t.tween_property(n, "scale", s * amt, 0.07)
	t.tween_property(n, "scale", s, 0.1)

func _process(delta: float) -> void:
	if _phase == "ready":
		_t += delta
		_alert.position.y = -230 - absf(sin(_t * 9.0)) * 16
		_held.rotation = sin(_t * 14.0) * 0.12
		_worker.rotation = sin(_t * 7.0) * 0.04
	elif _worker:
		_worker.rotation = 0.0
