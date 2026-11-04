extends Node
## Headless test suite:  godot --headless --path . --fixed-fps 60 tests/run_tests.tscn
## Exit code 0 = all passed.

var fails := 0
var checks := 0

func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		printerr("FAIL: ", what)

func _ready() -> void:
	Save.path = "user://test_save.json"
	await _run_all()
	print("TESTS: %d checks, %d failed" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)

func _run_all() -> void:
	test_scripts_load()
	test_assets()
	test_level_layout()
	test_save()
	await test_movement()
	await test_hits_and_intern()
	await test_promotion_and_score()
	await test_fairness()
	await test_joystick()
	await test_game_over()
	await test_victory()
	await test_pause()

func test_scripts_load() -> void:
	for p in _files("res://game", ".gd") + _files("res://tests", ".gd"):
		ok(load(p) != null, "script loads: " + p)

func _files(dir: String, ext: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_files(dir + "/" + sub, ext))
	return out

func test_assets() -> void:
	var d := LevelData.level_dept()
	var names := ["hang", "climb_a", "climb_b", "side", "hit", "fall", "victory", "mgr_hang", "mgr_climb", "intern", "life",
		"badge", "ac_unit", "ficus", "pigeon", "win_boarded", "rooftop", "logo", "ceo_sit", "ceo_cheer", "bg_sky", "bg_penthouse"]
	for pose in ["idle", "ready", "throw"]:
		names.append("%s_%s" % [d.id, pose])
	names.append("win_" + d.id)
	names.append("open_" + d.id)
	for p in d.patterns:
		names.append(p[1])
	for k in LevelData.PROJECTILES:
		names.append(k)
	for n in names:
		ok(Art.tex(n) != null, "texture exists: " + n)
	for s in ["climb", "shimmy", "bump", "window", "throw", "whoosh", "hit", "pop", "coo", "promote", "intern", "ding", "victory", "gameover", "fall", "click", "music_elevator"]:
		ok(ResourceLoader.exists("res://assets/audio/%s.ogg" % s), "audio exists: " + s)
	ok(Art.font() != null and Art.small_font() != null, "fonts load")

func test_level_layout() -> void:
	# every floor keeps >= 2 open windows, ledge rows are free, the rooftop is reachable from the street
	for f in range(1, Cfg.FLOORS + 1):
		var blocked := 0
		for c in Cfg.COLS:
			if LevelData.is_blocked(c, f * 4 + 1):
				blocked += 1
			ok(not LevelData.is_blocked(c, f * 4) and not LevelData.is_blocked(c, f * 4 + 3), "ledge rows free f%d c%d" % [f, c])
		ok(Cfg.COLS - blocked >= 2, "floor %d keeps 2 open columns" % f)
	var seen := {Vector2i(2, 0): true}
	var q := [Vector2i(2, 0)]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x < 0 or n.x >= Cfg.COLS or n.y < 0 or n.y > Cfg.TOP_ROW or seen.has(n) or LevelData.is_blocked(n.x, n.y):
				continue
			seen[n] = true
			q.append(n)
	ok(seen.has(Vector2i(2, Cfg.TOP_ROW)), "rooftop reachable")
	for b in LevelData.BADGES:
		ok(seen.has(Vector2i(int(b[0]), int(b[1]))), "badge reachable %s" % [b])
	ok(LevelData.dept_index_for_floor(0) == -1 and LevelData.dept_index_for_floor(1) == 0 and LevelData.dept_index_for_floor(Cfg.FLOORS + 1) == 1, "dept mapping")
	ok(is_equal_approx(LevelData.ramp(1), 0.0) and is_equal_approx(LevelData.ramp(Cfg.FLOORS), 1.0), "difficulty ramp 0..1")

func test_save() -> void:
	if FileAccess.file_exists(Save.path):
		DirAccess.remove_absolute(Save.path)
	Save.high_score = 0
	Save.best_floor = 0
	ok(Save.submit(500, 3), "first score is a record")
	ok(not Save.submit(200, 2), "lower score is not a record")
	Save.high_score = 0
	Save.load_file()
	ok(Save.high_score == 500 and Save.best_floor == 3, "high score persisted (%d, %d)" % [Save.high_score, Save.best_floor])

func _run() -> Run:
	var r := Run.new()
	add_child(r)
	r.director.enabled = false
	return r

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func test_movement() -> void:
	var r := _run()
	var p := r.player
	p.try_move(Vector2i(0, -1))
	await _wait(Cfg.MOVE_UP_TIME + 0.1)
	ok(p.row == 1 and p.col == 2, "climb up one row")
	ok(p.position.is_equal_approx(Cfg.cell_pos(2, 1)), "position snapped to cell")
	p.try_move(Vector2i(1, 0))
	await _wait(Cfg.MOVE_SIDE_TIME + 0.1)
	ok(p.col == 3, "move right")
	p.try_move(Vector2i(0, 1))
	await _wait(Cfg.MOVE_DOWN_TIME + 0.1)
	ok(p.row == 0, "move down")
	p.try_move(Vector2i(0, 1))
	await _wait(0.2)
	ok(p.row == 0, "cannot go below the street")
	# blocked window: floor 1 col 1 is boarded -> row 5 blocked
	p.col = 1
	p.row = 4
	p.position = Cfg.cell_pos(1, 4)
	p.try_move(Vector2i(0, -1))
	await _wait(0.3)
	ok(p.row == 4, "boarded window blocks climbing")
	ok(r.max_row >= 1 and r.score >= Cfg.SCORE_ROW, "climbing scores")
	r.queue_free()

func test_hits_and_intern() -> void:
	var r := _run()
	var p := r.player
	r.spawn_projectile("bs", "drop", p.body_pos() + Vector2(0, -60), 1.0)
	await _wait(0.2)
	ok(r.lives == Cfg.START_LIVES - 1, "hit removes a life")
	ok(p.invuln > 0.0 and p.state == Player.State.STUNNED, "hit stuns + invulnerability")
	r.spawn_projectile("bs", "drop", p.body_pos() + Vector2(0, -60), 1.0)
	await _wait(0.2)
	ok(r.lives == Cfg.START_LIVES - 1, "invulnerable right after a hit")
	await _wait(Cfg.INVULN_TIME)
	p.promote()
	ok(p.is_manager() and p.has_intern, "promotion gives manager + intern")
	r.spawn_projectile("crt", "drop", p.body_pos() + Vector2(0, -60), 1.0)
	await _wait(0.2)
	ok(r.lives == Cfg.START_LIVES - 1 and not p.has_intern, "intern absorbs exactly one hit")
	ok(p.is_manager(), "still a manager after the intern is gone")
	r.queue_free()

func test_promotion_and_score() -> void:
	var r := _run()
	var p := r.player
	var b: Array = LevelData.BADGES[0]
	p.col = int(b[0])
	p.row = int(b[1]) - 1
	p.position = Cfg.cell_pos(p.col, p.row)
	var before := r.score
	p.try_move(Vector2i(0, -1))
	await _wait(Cfg.MOVE_UP_TIME + 0.1)
	ok(p.is_manager() and r.badges == 1, "badge promotes")
	ok(r.score >= before + Cfg.SCORE_BADGE, "badge scores")
	ok(not r.building.badge_nodes.has(Vector2i(int(b[0]), int(b[1]))), "badge consumed")
	await _wait(Cfg.PROMO_TIME + 0.2)
	ok(not p.is_manager() and not p.has_intern, "promotion expires")
	r.queue_free()

func test_fairness() -> void:
	var r := _run()
	var dir := r.director
	r.player.col = 2
	r.player.row = 8
	dir._active = [{"cols": [1, 3], "sweep": false, "until": 999.0}]
	ok(not dir._fair([2]), "never threaten the player's column and both neighbours")
	ok(dir._fair([4]), "allowed while a neighbour stays safe")
	dir._active = []
	r.queue_free()

func test_joystick() -> void:
	# events are fed straight to the joystick in viewport coordinates (headless has no real window transform)
	var r := _run()
	var j := r.joystick
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.pressed = true
	t.position = Vector2(540, 1500)
	j._input(t)
	var dr := InputEventScreenDrag.new()
	dr.index = 0
	dr.position = Vector2(545, 1400)
	j._input(dr)
	ok(j.dir == Vector2i(0, -1), "joystick drag up = climb (%s)" % j.dir)
	dr.position = Vector2(680, 1490)
	j._input(dr)
	ok(j.dir == Vector2i(1, 0), "joystick drag right")
	dr.position = Vector2(560, 1480)
	j._input(dr)
	ok(j.dir == Vector2i.ZERO, "inside the deadzone = no move")
	t.pressed = false
	j._input(t)
	ok(j.dir == Vector2i.ZERO and not j.active, "release stops")
	var top := InputEventScreenTouch.new()
	top.index = 0
	top.pressed = true
	top.position = Vector2(540, 60)
	j._input(top)
	ok(not j.active, "HUD strip is not a joystick zone")
	top.pressed = false
	j._input(top)
	await _wait(0.05)
	r.queue_free()

func test_game_over() -> void:
	var r := _run()
	r.lives = 1
	r.spawn_projectile("bs", "drop", r.player.body_pos() + Vector2(0, -60), 1.0)
	await _wait(0.2)
	ok(r.state == "dying", "last life -> falling")
	await _wait(2.0)
	ok(r.state == "over" and r._overlay != null, "game over screen")
	var restarted := [false]
	r.restart_requested.connect(func(): restarted[0] = true)
	var btn := _find_button(r._overlay, "REAPPLY")
	ok(btn != null, "REAPPLY button exists")
	if btn:
		btn.pressed.emit()
	ok(restarted[0], "REAPPLY restarts")
	r.queue_free()

func test_victory() -> void:
	var r := _run()
	r.player.row = Cfg.TOP_ROW - 1
	r.player.position = Cfg.cell_pos(2, r.player.row)
	r.player.try_move(Vector2i(0, -1))
	await _wait(1.0)
	ok(r.state == "victory", "reaching the rooftop starts the ending")
	ok(r.score >= Cfg.SCORE_ROOF + Cfg.START_LIVES * Cfg.SCORE_LIFE, "rooftop + lives bonus")
	await _wait(8.0)
	ok(r._overlay != null and _find_button(r._overlay, "PLAY AGAIN") != null, "results with PLAY AGAIN")
	r.queue_free()

func test_pause() -> void:
	var r := _run()
	r.toggle_pause()
	ok(get_tree().paused and r._overlay != null, "pause opens coffee break")
	var row := r.player.row
	r.player.held_dir = Vector2i(0, -1)
	await get_tree().create_timer(0.5, true).timeout
	ok(r.player.row == row, "paused game does not move")
	r.toggle_pause()
	ok(not get_tree().paused, "resume")
	r.queue_free()

func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text:
		return n
	for c in n.get_children():
		var b := _find_button(c, text)
		if b:
			return b
	return null
