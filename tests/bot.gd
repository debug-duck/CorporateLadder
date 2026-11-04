class_name Bot
extends RefCounted
## A simple "attentive player" autopilot: reads the same warnings a human sees (danger lanes, row arrows,
## incoming objects) and climbs. Used by the playthrough test and the screenshot tool.

var run: Run
var skill := 1.0          # 1 = reacts to everything; lower = sometimes ignores a warning
var _ignore: Dictionary = {}

func _init(r: Run, s := 1.0) -> void:
	run = r
	skill = s

func _col_of(x: float) -> int:
	return clampi(int(round((x - Cfg.CENTER_X) / Cfg.COL_W)) + 2, 0, Cfg.COLS - 1)

func _danger() -> Dictionary:
	var p := run.player
	var body := p.body_pos()
	var cols := {}
	var rows := {}
	for m in run.telegraph.marks:
		if not _noticed(m):
			continue
		if m.type == "lane":
			if m.color.g > 0.5:
				continue          # orange lane = a splitting object's path; it bursts above the player (centre stays safe)
			if m.from_y < body.y:
				cols[_col_of(m.x)] = true
		else:
			rows[int(round(m.y))] = true
	for n in run.projectiles.get_children():
		var pr := n as Projectile
		if pr == null or pr.dead:
			continue
		if pr.motion == "sweep":
			rows[int(round(pr.sweep_y))] = true
		elif pr.motion == "split":
			var sc := _col_of(pr.lane())
			cols[sc - 1] = true
			cols[sc + 1] = true
		elif pr.position.y < body.y + 40:
			cols[_col_of(pr.lane())] = true
			if pr.motion == "drift":
				cols[_col_of(pr.position.x)] = true
	return {"cols": cols, "rows": rows}

func _noticed(m: Dictionary) -> bool:
	if skill >= 1.0:
		return true
	var k := str(m.get("x", m.get("y", 0))) + str(m.until)
	if not _ignore.has(k):
		_ignore[k] = randf() > skill
	return not _ignore[k]

func _row_danger(rows: Dictionary, r: int) -> bool:
	var y := Cfg.row_y(r) + Cfg.BODY_OFFSET.y
	for ry in rows:
		if absf(float(ry) - y) < 120:
			return true
	return false

func _free(c: int, r: int) -> bool:
	return c >= 0 and c < Cfg.COLS and r >= 0 and (r >= Cfg.TOP_ROW or not LevelData.is_blocked(c, r))

func decide() -> Vector2i:
	var p := run.player
	var d := _danger()
	var c := p.col
	var r := p.row
	if _row_danger(d.rows, r):
		if _free(c, r + 1) and not d.cols.has(c):
			return Vector2i(0, -1)
		if _free(c, r - 1):
			return Vector2i(0, 1)
	if d.cols.has(c):
		for dc in [1, -1, 2, -2]:
			var nc: int = c + dc
			if nc < 0 or nc >= Cfg.COLS or d.cols.has(nc):
				continue
			var step: int = signi(dc)
			if _free(c + step, r) and not d.cols.has(c + step) or absi(dc) == 1:
				if _free(c + step, r):
					return Vector2i(step, 0)
		if _free(c, r - 1):
			return Vector2i(0, 1)
		return Vector2i.ZERO
	if not _free(c, r + 1):
		# walk to the nearest column that is free above (ledge rows are always free sideways)
		for dc in [1, -1, 2, -2, 3, -3, 4, -4]:
			var nc: int = c + dc
			if nc >= 0 and nc < Cfg.COLS and _free(nc, r + 1) and not d.cols.has(c + signi(dc)):
				return Vector2i(signi(dc), 0) if _free(c + signi(dc), r) else Vector2i(0, 1)
		return Vector2i(0, 1)
	if _row_danger(d.rows, r + 1):
		return Vector2i.ZERO
	# head for badges in the next rows
	return Vector2i(0, -1)
