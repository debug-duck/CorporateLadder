extends Node
## Headless bot playthrough: the attentive bot must reach the CEO; prints pacing + combat stats.
## godot --headless --path . --fixed-fps 60 tests/playthrough.tscn [-- --runs=N --skill=0.8]

var runs := 3
var skill := 0.8
var _i := 0
var run: Run
var _t := 0.0
var results: Array = []
var bot: Bot

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.get_slice("=", 1))
		elif a.begins_with("--skill="):
			skill = float(a.get_slice("=", 1))
	_next()

func _next() -> void:
	if run:
		run.queue_free()
	_t = 0.0
	run = Run.new()
	add_child(run)
	bot = Bot.new(run, skill)
	run.bot = bot.decide

func _process(delta: float) -> void:
	_t += delta
	if run.state in ["over", "victory"] or _t > 300.0:
		var won := run.state == "victory"
		var ft := PackedStringArray()
		for x in run.floor_times:
			ft.append("%.0f" % x)
		print("RUN %d: %s time=%.1fs floor=%d lives=%d hits=%d dodges=%d badges=%d score=%d dir=%s floors_at=[%s]" % [
			_i, "WON" if won else ("LOST" if run.state == "over" else "TIMEOUT"), run.time, run.max_floor, run.lives,
			run.hits, run.dodges, run.badges, run.score, str(run.director.stats), ", ".join(ft)])
		results.append(won)
		_i += 1
		if _i >= runs:
			var wins := results.count(true)
			print("PLAYTHROUGH wins %d/%d" % [wins, runs])
			get_tree().quit(0 if wins > 0 or skill < 1.0 else 1)
			return
		_next()
