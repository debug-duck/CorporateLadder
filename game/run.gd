class_name Run
extends Node2D
## One attempt at the tower: world (building, player, projectiles, warnings), camera, HUD, joystick,
## hazard director, scoring, lives, pause, game over and the CEO ending. Main creates a fresh Run per attempt,
## so "REAPPLY" is an instant, clean restart.

signal quit_to_title
signal restart_requested

var building: Building
var player: Player
var camera: Camera2D
var telegraph: Telegraph
var director: HazardDirector
var hud: Hud
var joystick: Joystick
var projectiles: Node2D
var fx: Node2D
var ui: CanvasLayer
var bg: TextureRect

var score := 0
var lives := Cfg.START_LIVES
var max_row := 0
var max_floor := 0
var dept_i := -1
var state := "play"           # play | dying | over | victory
var time := 0.0
var dodges := 0
var badges := 0
var hits := 0
var floor_times: Array = []
var bot: Callable             # tests: optional autopilot returning a Vector2i each frame
var _shake := 0.0
var _overlay: Control
var _promo_shown := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var bgl := CanvasLayer.new()
	bgl.layer = -10
	add_child(bgl)
	bg = TextureRect.new()
	bg.texture = Art.tex("bg_sky")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bgl.add_child(bg)
	building = Building.new()
	add_child(building)
	telegraph = Telegraph.new()
	add_child(telegraph)
	player = Player.new()
	add_child(player)
	projectiles = Node2D.new()
	add_child(projectiles)
	fx = Node2D.new()
	add_child(fx)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	camera.position = Vector2(Cfg.CENTER_X, _cam_target_y())
	hud = Hud.new()
	add_child(hud)
	hud.pause_pressed.connect(toggle_pause)
	hud.mute_pressed.connect(func():
		Sfx.toggle_mute()
		hud.refresh_mute())
	joystick = Joystick.new()
	hud.add_child(joystick)
	ui = CanvasLayer.new()
	ui.layer = 20
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	director = HazardDirector.new()
	director.run = self
	add_child(director)
	player.moved.connect(_on_moved)
	player.blocked_bump.connect(func(): Sfx.play("bump", -6.0))
	player.reached_top.connect(_victory)
	player.fell_off.connect(_game_over)
	hud.set_score(0, Save.high_score)
	hud.set_lives(lives)
	hud.set_floor(0, "LOBBY", Color("ffd34a"))
	Sfx.music("music_elevator")
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(func(): hud.banner("CORPORATE HQ", "CLIMB THE CORPORATE LADDER. LITERALLY.", Color("ffd34a")))

func dept_index() -> int:
	return dept_i

func _cam_target_y() -> float:
	var vh := get_viewport_rect().size.y
	var y := player.position.y + 80.0 - vh * 0.21
	return minf(y, Cfg.STREET_Y + 420.0 - vh * 0.5)

# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	if state == "play":
		time += delta
		player.held_dir = _input_dir()
	else:
		player.held_dir = Vector2i.ZERO
	if state != "dying" and state != "over":
		camera.position.y = lerpf(camera.position.y, _cam_target_y(), 1.0 - exp(-delta * 7.0))
	camera.position.x = Cfg.CENTER_X
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 26.0 * _shake * _shake
	else:
		camera.offset = Vector2.ZERO
	_update_bg()
	if state == "play":
		_collisions()
		building.scare_pigeons(player.position + Vector2(0, 60))
	var pt := player.manager_time
	if absf(pt - _promo_shown) > 0.05 or (pt <= 0.0 and _promo_shown > 0.0):
		_promo_shown = maxf(pt, 0.0)
		hud.set_promo(_promo_shown)

func _input_dir() -> Vector2i:
	if bot.is_valid():
		return bot.call()
	if joystick.dir != Vector2i.ZERO:
		return joystick.dir
	var d := Vector2i.ZERO
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		d = Vector2i(0, -1)
	elif Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		d = Vector2i(0, 1)
	elif Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		d = Vector2i(-1, 0)
	elif Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		d = Vector2i(1, 0)
	return d

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_ESCAPE, KEY_P]:
			toggle_pause()
		elif event.physical_keycode == KEY_M:
			Sfx.toggle_mute()
			hud.refresh_mute()

func _update_bg() -> void:
	var vs := get_viewport_rect().size
	var tex := bg.texture
	if tex == null:
		return
	var s := maxf(vs.x / tex.get_width(), vs.y * 1.3 / tex.get_height())
	bg.size = Vector2(tex.get_width(), tex.get_height()) * s
	var prog := clampf(-player.position.y / (Cfg.TOP_ROW * Cfg.ROW_H), 0.0, 1.0)
	bg.position = Vector2((vs.x - bg.size.x) * 0.5, -(bg.size.y - vs.y) * (1.0 - prog))

# ------------------------------------------------------------------ projectiles
func spawn_projectile(kind: String, motion: String, from: Vector2, mult: float) -> Projectile:
	var p := Projectile.new()
	p.setup(kind, motion, from, mult)
	projectiles.add_child(p)
	if motion == "split":
		p.split_now.connect(_on_split)
	return p

func _on_split(p: Projectile) -> void:
	var pos := p.position
	burst(pos, [Color("ff5aa5"), Color("ffd34a"), Color("4f9dff"), Color("5ed37a")] if LevelData.PROJECTILES[p.kind].get("confetti", false) else [Color("e8e2d0"), Color("9a9a9a")], 26)
	Sfx.play("pop", -2.0)
	var col := int(round((pos.x - Cfg.CENTER_X) / Cfg.COL_W)) + 2
	for dc in [-1, 1]:
		var c: int = col + dc
		if c < 0 or c >= Cfg.COLS:
			continue
		var ch := spawn_projectile(p.child, "drift", pos, p.speed_mult)
		ch.aim_drift(Cfg.col_x(c))
	p.queue_free()

func _collisions() -> void:
	var body := player.body_pos()
	var vh := get_viewport_rect().size.y
	var bottom := camera.get_screen_center_position().y + vh * 0.5 + 200
	for n in projectiles.get_children():
		var p := n as Projectile
		if p == null or p.dead:
			continue
		if p.position.y > bottom or p.position.x < -300 or p.position.x > Cfg.W + 300:
			p.queue_free()
			continue
		var hit_r := p.radius + Cfg.PLAYER_RADIUS
		if p.position.distance_to(body) < hit_r and player.invuln <= 0.0 \
				and player.state != Player.State.FALLING and player.state != Player.State.VICTORY:
			_hit(p)
			continue
		if not p.dodge_checked:
			if p.motion == "sweep":
				var passed := (p.vel.x > 0 and p.position.x > body.x + 60) or (p.vel.x < 0 and p.position.x < body.x - 60)
				if passed:
					p.dodge_checked = true
					if absf(p.position.y - body.y) < 170:
						_dodge(p)
			elif p.position.y > body.y + 60:
				p.dodge_checked = true
				if absf(p.position.x - body.x) < 240:
					_dodge(p)

func _dodge(p: Projectile) -> void:
	dodges += 1
	add_score(Cfg.SCORE_DODGE)
	float_text(player.position + Vector2(0, -70), "+%d" % Cfg.SCORE_DODGE, Color("ffe14d"), 44)
	if dodges % 5 == 0:
		float_text(player.position + Vector2(0, -130), ["NICE DODGE!", "NOT TODAY!", "MISSED ME!", "TOO SLOW, KAREN!", "AGILE!"].pick_random(), Color.WHITE, 50)
	Sfx.play("whoosh", -12.0, 0.1)

func _hit(p: Projectile) -> void:
	var where := p.position
	var def: Dictionary = LevelData.PROJECTILES[p.kind]
	p.dead = true
	p.queue_free()
	if def.get("splat", false):
		burst(where, [Color("7a4a1e"), Color("5a3412")], 22)
	else:
		burst(where, [Color("ffffff"), Color("dfe6f2")], 14)
	if player.has_intern:
		_intern_gag(player.spend_intern())
		return
	hits += 1
	lives -= 1
	hud.set_lives(lives)
	hud.lose_life_fx()
	shake(1.0 if def.get("heavy", false) else 0.75)
	Sfx.play("hit", 0.0)
	if lives <= 0:
		_die()
		return
	player.stun()
	float_text(player.position + Vector2(0, -60), ["OUCH!", "NOT MY JOB!", "WORKPLACE INJURY!", "I'LL CC HR!", "WHY?!"].pick_random(), Color("ff5a5a"), 56)

func _intern_gag(at: Vector2) -> void:
	Sfx.play("intern", 0.0)
	shake(0.4)
	var s := Sprite2D.new()
	s.texture = Art.tex("intern")
	s.scale = Vector2.ONE * 0.42
	s.position = at
	fx.add_child(s)
	var dir := -1.0 if at.x > Cfg.CENTER_X else 1.0
	var t := s.create_tween()
	t.tween_property(s, "position", at + Vector2(dir * 520, -260), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(s, "rotation", dir * TAU * 1.5, 0.55)
	t.tween_property(s, "position", at + Vector2(dir * 760, 1400), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(s, "rotation", dir * TAU * 4.0, 1.2)
	t.tween_callback(s.queue_free)
	bubble(at + Vector2(dir * 200, -120), "GREAT LEARNING OPPORTUNITY!", 2.2)
	float_text(player.position + Vector2(0, -230), "INTERN SHIELD!", Color("ffd34a"), 52)

func _die() -> void:
	state = "dying"
	director.clear()
	joystick.enabled = false
	Sfx.play("fall", 0.0)
	Sfx.stop_music()
	bubble(player.position + Vector2(0, -120), "AAAAAAH!", 1.4)
	player.fall()

# ------------------------------------------------------------------ progress
func _on_moved(c: int, r: int) -> void:
	hud.hide_hint()
	if r > max_row:
		add_score(Cfg.SCORE_ROW * (r - max_row))
		max_row = r
	var f := Cfg.floor_of_row(r)
	if f > max_floor and f <= Cfg.FLOORS:
		max_floor = f
		print_verbose("floor %d at %.1f s" % [f, time])
		floor_times.append(time)
		if f > 1:
			add_score(Cfg.SCORE_FLOOR)
	var di := LevelData.dept_index_for_floor(f)
	var d := LevelData.dept(di)
	hud.set_floor(f, d.name if di >= 0 else "LOBBY", d.color if di >= 0 else Color("ffd34a"))
	if di > dept_i:
		dept_i = di
		if di == 0:
			hud.banner("WELCOME TO " + String(d.name), String(d.subtitle), d.color)
			Sfx.play("ding", -2.0)
		else:
			hud.banner(String(d.name), String(d.subtitle), d.color)
			Sfx.play("ding", -2.0)
	hud.set_progress(float(r) / float(Cfg.TOP_ROW))
	if building.take_badge(Vector2i(c, r)):
		_promoted()

func _promoted() -> void:
	badges += 1
	add_score(Cfg.SCORE_BADGE)
	player.promote()
	Sfx.play("promote", 0.0)
	hud.flash_text("PROMOTED!", Color("ffd34a"), 520, 110)
	burst(player.position + Vector2(0, 80), [Color("ffd34a"), Color("ffffff"), Color("4f9dff")], 30)
	bubble(player.position + Vector2(140, -60), "I'M A MANAGER NOW!", 1.6)

func add_score(n: int) -> void:
	score += n
	hud.set_score(score, Save.high_score)
	hud.bump_score()

# ------------------------------------------------------------------ endings
func _game_over() -> void:
	state = "over"
	Sfx.play("gameover", 0.0)
	var record := Save.submit(score, max_floor)
	_overlay = Screens.game_over(score, max_floor, record, Save.high_score,
		func(): restart_requested.emit(), func(): quit_to_title.emit())
	ui.add_child(_overlay)
	_pop_in(_overlay)

func _victory() -> void:
	state = "victory"
	director.clear()
	joystick.enabled = false
	for p in projectiles.get_children():
		p.queue_free()
	hud.set_progress(1.0)
	var lives_bonus := lives * Cfg.SCORE_LIFE
	add_score(Cfg.SCORE_ROOF + lives_bonus)
	var record := Save.submit(score, Cfg.FLOORS)
	Sfx.stop_music()
	var v := Victory.new()
	ui.add_child(v)
	var secs := int(time)
	var lines := ["CLIMB + DODGES + PROMOTIONS", "ROOFTOP BONUS  +" + Hud._fmt(Cfg.SCORE_ROOF),
		"LIVES LEFT %d  x %s  =  +%s" % [lives, Hud._fmt(Cfg.SCORE_LIFE), Hud._fmt(lives_bonus)],
		"TIME %d:%02d   ·   DODGES %d   ·   PROMOTIONS %d" % [secs / 60, secs % 60, dodges, badges]]
	v.finished.connect(func():
		_overlay = Screens.results(score, lines, record, func(): restart_requested.emit(), func(): quit_to_title.emit())
		ui.add_child(_overlay)
		_pop_in(_overlay))

func _pop_in(c: Control) -> void:
	c.modulate.a = 0.0
	var t := c.create_tween()
	t.tween_property(c, "modulate:a", 1.0, 0.3)

func toggle_pause() -> void:
	if state != "play":
		return
	if get_tree().paused:
		_resume()
		return
	get_tree().paused = true
	Sfx.duck(true)
	_overlay = Screens.pause_menu(_resume, func():
		get_tree().paused = false
		restart_requested.emit(), func():
		get_tree().paused = false
		quit_to_title.emit())
	ui.add_child(_overlay)

func _resume() -> void:
	get_tree().paused = false
	Sfx.duck(false)
	if _overlay:
		_overlay.queue_free()
		_overlay = null

func _notification(what: int) -> void:
	# phone: app sent to background -> pause
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "play" and not get_tree().paused and not bot.is_valid():
		toggle_pause()

# ------------------------------------------------------------------ fx helpers
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func float_text(pos: Vector2, text: String, col: Color, size := 48) -> void:
	var l := Art.label(text, size, col, 12)
	l.size = Vector2(700, size * 1.4)
	l.position = pos - l.size * 0.5
	l.position.x = clampf(l.position.x, 0, Cfg.W - 700)
	fx.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "position:y", l.position.y - 110, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	t.tween_callback(l.queue_free)

func bubble(pos: Vector2, text: String, life := 1.8) -> void:
	if text == "":
		return
	var b := SpeechBubble.make(text)
	fx.add_child(b)
	b.place(pos)
	b.expire(life)

func burst(pos: Vector2, colors: Array, n := 20) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = n
	p.lifetime = 0.9
	p.position = pos
	p.direction = Vector2(0, -1)
	p.spread = 180
	p.initial_velocity_min = 220
	p.initial_velocity_max = 520
	p.gravity = Vector2(0, 1100)
	p.scale_amount_min = 8
	p.scale_amount_max = 16
	p.angular_velocity_min = -400
	p.angular_velocity_max = 400
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for i in colors.size():
		g.add_point(float(i) / maxf(1.0, colors.size() - 1), colors[i])
	p.color_initial_ramp = g
	fx.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.3, false).timeout.connect(p.queue_free)
