extends Node
## Visual QA of the scripted moments: title, intern shield, game over, CEO ending, results.
## xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 --fixed-fps 60 tools/dev/shots_flow.tscn

var step := 0
var t := 0.0
var run: Run
var layer: CanvasLayer
var _done := {}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	layer = CanvasLayer.new()
	add_child(layer)
	layer.add_child(Screens.title(12345, 9, func(): pass))

func _shot(n: String) -> void:
	if _done.has(n):
		return
	_done[n] = true
	get_viewport().get_texture().get_image().save_png("user://shots/flow_%s.png" % n)
	print("shot ", n)

func _new_run(row: int) -> void:
	if run:
		run.queue_free()
	run = Run.new()
	add_child(run)
	run.director.enabled = false
	run.player.row = row
	run.player.col = 2
	run.player.position = Cfg.cell_pos(2, row)
	run.max_row = row
	run._on_moved(2, row)

func _process(delta: float) -> void:
	t += delta
	match step:
		0:
			if t > 1.0:
				_shot("title")
				layer.queue_free()
				_new_run(22)
				run.player.promote()
				run._promoted()
				step = 1; t = 0
		1:
			if t > 0.6:
				_shot("promoted")
				var w: OfficeWindow = run.building.window_at(7, 1)
				w.throw_item("bs", 3.0)
				run.telegraph.lane(Cfg.col_x(1), w.global_position.y, 3.0)
				run.spawn_projectile("ppt", "drop", run.player.body_pos() + Vector2(0, -260), 1.0)
				step = 2; t = 0
		2:
			if t > 0.95:
				_shot("intern")
				step = 3; t = 0
		3:
			if t > 1.2:
				_new_run(30)
				run.lives = 1
				run.spawn_projectile("bs", "drop", run.player.position + Vector2(0, -300), 1.0)
				step = 4; t = 0
		4:
			if t > 0.75:
				_shot("falling")
			if t > 3.2:
				_shot("gameover")
				_new_run(Cfg.TOP_ROW - 1)
				run.player.try_move(Vector2i(0, -1))
				step = 5; t = 0
		5:
			if t > 3.9:
				_shot("victory")
			if t > 9.5:
				_shot("results")
				get_tree().quit()
