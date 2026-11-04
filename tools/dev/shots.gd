extends Node
## Visual QA: plays the game with the bot and saves screenshots to user://shots/ (see README).
## xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 tools/dev/shots.tscn

var run: Run
var bot: Bot
var t := 0.0
var times := [1.2, 7.0, 12.0, 17.0, 22.0, 27.0, 33.0, 40.0, 48.0, 56.0, 64.0, 72.0]
var n := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	run = Run.new()
	add_child(run)
	var skill := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--skill="):
			skill = float(a.get_slice("=", 1))
	bot = Bot.new(run, skill)
	run.bot = bot.decide

func _process(delta: float) -> void:
	t += delta
	if n < times.size() and t >= times[n]:
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://shots/shot_%02d.png" % n)
		print("shot ", n, " t=", t, " row=", run.player.row, " lives=", run.lives, " score=", run.score)
		n += 1
	if n >= times.size():
		get_tree().quit()
