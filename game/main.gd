extends Node
## App flow: title -> Run -> (game over | ending) -> REAPPLY / PLAY AGAIN (fresh Run) or back to the title.
## `--autostart` (after `--`) skips the title (dev screenshots / tests).

var run: Run
var _title: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.set_default_clear_color(Color("8fc4ef"))
	if "--autostart" in OS.get_cmdline_user_args():
		start_run()
	else:
		show_title()

func show_title() -> void:
	get_tree().paused = false
	_clear_run()
	Sfx.music("music_elevator")
	_title = CanvasLayer.new()
	add_child(_title)
	_title.add_child(Screens.title(Save.high_score, Save.best_floor, start_run))

func start_run() -> void:
	get_tree().paused = false
	if _title:
		_title.queue_free()
		_title = null
	_clear_run()
	run = Run.new()
	add_child(run)
	run.restart_requested.connect(start_run, CONNECT_DEFERRED)
	run.quit_to_title.connect(show_title, CONNECT_DEFERRED)

func _clear_run() -> void:
	if run:
		run.queue_free()
		remove_child(run)
		run = null

func _unhandled_input(event: InputEvent) -> void:
	if _title and event is InputEventKey and event.pressed and event.physical_keycode in [KEY_ENTER, KEY_SPACE]:
		start_run()
