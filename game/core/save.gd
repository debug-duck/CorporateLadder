extends Node
## Autoload "Save": the high score, best floor and the mute switch in one tiny JSON file
## (user:// = app-private storage on Android). A broken file never blocks the game.

var path := "user://corporate_ladder.json"
var high_score := 0
var best_floor := 0
var muted := false
var runs := 0

func _ready() -> void:
	# Test/dev scenes launched explicitly get their own file so they never touch the player's record.
	for a in OS.get_cmdline_args():
		if a.ends_with(".tscn") and not a.ends_with("main.tscn"):
			path = "user://corporate_ladder_dev.json"
	load_file()

func load_file() -> void:
	if not FileAccess.file_exists(path):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if d is Dictionary:
		high_score = maxi(0, int(d.get("high_score", 0)))
		best_floor = maxi(0, int(d.get("best_floor", 0)))
		muted = bool(d.get("muted", false))
		runs = maxi(0, int(d.get("runs", 0)))

func write() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"high_score": high_score, "best_floor": best_floor, "muted": muted, "runs": runs}))

## Returns true when `score` is a new record.
func submit(score: int, floor_reached: int) -> bool:
	var record := score > high_score
	high_score = maxi(high_score, score)
	best_floor = maxi(best_floor, floor_reached)
	runs += 1
	write()
	return record

func set_muted(m: bool) -> void:
	muted = m
	write()
