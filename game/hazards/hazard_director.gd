class_name HazardDirector
extends Node
## Decides who throws what, when, from which window - and keeps it FAIR:
##  * every throw is announced (window opens, item raised, "!" and a danger lane) for `warn` seconds;
##  * never more simultaneous throws than the department allows;
##  * a falling hazard is only allowed if at least one neighbouring, unblocked column stays safe;
##  * row sweeps run alone (dodging one means moving up/down, so nothing may force a sideways move then).

var run: Node          # Run (duck-typed to avoid a cyclic class reference)
var enabled := true
var _timer := 2.2
var _peek_timer := 1.5
var _now := 0.0
var _active: Array = []   # {cols:Array[int], sweep:bool, until:float}
var stats := {"throws": 0, "fail": 0, "busy": 0}

func _process(delta: float) -> void:
	_now += delta
	if not enabled or run == null:
		return
	_active = _active.filter(func(a): return a.until > _now)
	var di: int = run.dept_index()
	if di < 0 or di >= LevelData.LEVEL_DEPTS.size():
		_timer = minf(_timer, 1.4)
		return
	var d: Dictionary = LevelData.dept(di)
	var k := LevelData.ramp(_floor())
	_peek_timer -= delta
	if _peek_timer <= 0.0:
		_peek_timer = randf_range(1.4, 3.2)
		_ambient_peek(d)
	_timer -= delta
	if _timer > 0.0:
		return
	var max_active := mini(int(d.max_active), 1 if k < 0.1 else (2 if k < 0.45 else 3))
	if _active.size() >= max_active or _active.any(func(a): return a.sweep):
		stats.busy += 1
		_timer = 0.25
		return
	if _spawn(d):
		stats.throws += 1
		var iv: Array = d.interval
		# ramp: calm first floor (x1.35 interval) -> busy top floor (x0.7)
		_timer = randf_range(float(iv[0]), float(iv[1])) * lerpf(1.5, 0.72, k)
	else:
		stats.fail += 1
		_timer = 0.15

func _visible_top() -> float:
	var cam: Camera2D = run.camera
	return cam.get_screen_center_position().y - get_viewport().get_visible_rect().size.y * 0.5

func _floor() -> int:
	return clampi(run.player.row / Cfg.ROWS_PER_FLOOR, 1, Cfg.FLOORS)

func _pick_pattern(d: Dictionary) -> Array:
	var pool: Array = d.patterns.filter(func(p): return LevelData.floor_in_dept(_floor()) >= int(p[3]))
	var total := 0.0
	for p in pool:
		total += float(p[2])
	var r := randf() * total
	for p in pool:
		r -= float(p[2])
		if r <= 0.0:
			return p
	return pool[0]

func _threatened() -> Dictionary:
	var out := {}
	for a in _active:
		for c in a.cols:
			out[c] = true
	return out

## True if after threatening `cols` the player still has a safe column reachable sideways in one step (or stays put).
func _fair(cols: Array) -> bool:
	var th := _threatened()
	for c in cols:
		th[c] = true
	var p = run.player
	for dc in [0, -1, 1]:
		var c: int = p.col + dc
		if c < 0 or c >= Cfg.COLS or th.has(c):
			continue
		if dc != 0 and LevelData.is_blocked(c, p.row):
			continue
		return true
	return false

## Windows in column c whose throw position is on screen and clearly above the player.
func _windows_above(c: int) -> Array:
	var out: Array = []
	var top := _visible_top() + 200.0
	var by: float = run.player.body_pos().y - 200.0
	for f in range(1, Cfg.FLOORS + 1):
		var w: OfficeWindow = run.building.window_at(f, c)
		if w == null or not w.can_act():
			continue
		var y := w.global_position.y
		if y > top and y < by:
			out.append(w)
	return out

func _spawn(d: Dictionary) -> bool:
	var pat := _pick_pattern(d)
	var kind: String = pat[0]
	var item: String = pat[1]
	var p = run.player
	var warn: float = float(d.warn) * lerpf(1.1, 0.95, LevelData.ramp(_floor()))
	match kind:
		"sweep":
			if not _active.is_empty():
				return false
			return _sweep(d, item, warn)
		"double":
			var a: int = clampi(p.col + (0 if randf() < 0.5 else -1), 0, Cfg.COLS - 2)
			var cols := [a, a + 1]
			if not _fair(cols):
				return false
			var w1 := _windows_above(a)
			var w2 := _windows_above(a + 1)
			if w1.is_empty() or w2.is_empty():
				return false
			_throw(w1.pick_random(), item, "drop", warn, d, [a])
			_throw(w2.pick_random(), item, "drop", warn + 0.12, d, [a + 1])
			return true
		_:
			var order: Array = [p.col, p.col - 1, p.col + 1, p.col - 2, p.col + 2]
			if randf() > 0.68:
				order = [p.col + 1, p.col - 1, p.col, p.col + 2, p.col - 2] if randf() < 0.5 else [p.col - 1, p.col + 1, p.col, p.col - 2, p.col + 2]
			for tc in order:
				if tc < 0 or tc >= Cfg.COLS:
					continue
				var cols: Array = [tc]
				if kind == "split":
					cols = []
					for c in [tc - 1, tc + 1]:
						if c >= 0 and c < Cfg.COLS:
							cols.append(c)
				if not _fair(cols):
					continue
				if kind == "lob":
					var srcs: Array = []
					for dc in [-2, -1, 1, 2]:
						var c: int = tc + dc
						if c >= 0 and c < Cfg.COLS:
							srcs.append_array(_windows_above(c))
					if srcs.is_empty():
						continue
					_throw(srcs.pick_random(), item, "lob", warn, d, cols, tc)
					return true
				var ws := _windows_above(tc)
				if ws.is_empty():
					continue
				_throw(ws.pick_random(), item, kind, warn, d, cols, tc)
				return true
			return false

func _sweep(d: Dictionary, item: String, warn: float) -> bool:
	var p = run.player
	var side: int = 4 if p.col < 2 else (0 if p.col > 2 else [0, 4].pick_random())
	var f: int = clampi(p.row / Cfg.ROWS_PER_FLOOR, 1, Cfg.FLOORS)
	var w: OfficeWindow = null
	for ff in [f, f + 1, f - 1]:
		var cand: OfficeWindow = run.building.window_at(ff, side)
		if cand and cand.can_act() and cand.global_position.y > _visible_top() + 150:
			w = cand
			break
	if w == null:
		return false
	# aim one row above a climber who is on the move (where they are going), else at them
	var aim_row: int = p.row + (1 if p.held_dir.y < 0 and not LevelData.is_blocked(p.col, p.row + 1) else 0)
	var y: float = Cfg.row_y(aim_row) + Cfg.BODY_OFFSET.y
	var dir := 1.0 if side == 0 else -1.0
	_active.append({"cols": [], "sweep": true, "until": _now + warn + 0.35 + 2.4})
	run.telegraph.row(y, dir, warn + 0.5)
	w.released.connect(func(win: OfficeWindow):
		var pr: Projectile = run.spawn_projectile(item, "sweep", win.release_point(), _mult(d))
		pr.aim_sweep(dir, y)
		_maybe_shout(win, d), CONNECT_ONE_SHOT)
	w.throw_item(item, warn)
	return true

func _throw(w: OfficeWindow, item: String, motion: String, warn: float, d: Dictionary, cols: Array, tc := -1) -> void:
	var flight := 1.6
	var count := 1
	if motion == "burst":
		motion = "drop"
		count = 3
		flight += 0.6
	_active.append({"cols": cols, "sweep": false, "until": _now + warn + 0.2 + flight})
	var lane_from := w.global_position.y
	if motion == "lob":
		run.telegraph.lane(Cfg.col_x(tc), lane_from, warn + 1.0)
	elif motion == "split":
		run.telegraph.lane(Cfg.col_x(w.col), lane_from, warn + 0.4, Color(1, 0.6, 0.1))
		for c in cols:
			run.telegraph.lane(Cfg.col_x(c), run.player.body_pos().y - 420, warn + 1.1)
	else:
		run.telegraph.lane(Cfg.col_x(w.col), lane_from, warn + 0.9 + (count - 1) * 0.28)
	w.released.connect(func(win: OfficeWindow):
		for i in range(1, count):
			get_tree().create_timer(0.28 * i, false).timeout.connect(func():
				if is_instance_valid(win) and enabled:
					run.spawn_projectile(item, "drop", win.release_point(), _mult(d)))
		var pr: Projectile = run.spawn_projectile(item, motion, win.release_point(), _mult(d))
		if motion == "lob":
			pr.aim_lob(Cfg.col_x(tc))
		elif motion == "split":
			pr.split_y = run.player.body_pos().y - 380
		_maybe_shout(win, d), CONNECT_ONE_SHOT)
	w.throw_item(item, warn)

func _mult(d: Dictionary) -> float:
	return float(d.speed) * lerpf(0.95, 1.06, LevelData.ramp(_floor()))

func _maybe_shout(w: OfficeWindow, d: Dictionary) -> void:
	if randf() < 0.22:
		run.bubble(w.global_position + Vector2(0, -150), String(d.shout))

func _ambient_peek(d: Dictionary) -> void:
	var p = run.player
	var top := _visible_top() + 160
	var cands: Array = []
	for f in range(1, Cfg.FLOORS + 1):
		for c in Cfg.COLS:
			var w: OfficeWindow = run.building.window_at(f, c)
			if w == null or not w.can_act():
				continue
			if w.global_position.y < top or w.global_position.y > top + 1500:
				continue
			if absi(c - p.col) <= 1 and absi(f * 4 + 1 - p.row) <= 4:
				continue
			cands.append(w)
	if cands.is_empty():
		return
	var w: OfficeWindow = cands.pick_random()
	w.peek(randf_range(1.2, 2.2))
	if randf() < 0.3:
		run.bubble(w.global_position + Vector2(0, -150), String(d.shout))

func clear() -> void:
	enabled = false
	_active.clear()
