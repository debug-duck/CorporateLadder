extends Node
## Autoload "Sfx": one-shot sounds + the looping elevator music. Streams are res://assets/audio/<name>.ogg;
## a missing file is skipped silently so audio can never block gameplay.

var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _last: Dictionary = {}
var music_db := -11.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_apply_mute()

func _stream(n: String) -> AudioStream:
	if not _cache.has(n):
		var p := "res://assets/audio/%s.ogg" % n
		_cache[n] = load(p) if ResourceLoader.exists(p) else null
	return _cache[n]

func play(n: String, db := 0.0, pitch_var := 0.06, pitch := 1.0) -> void:
	if Save.muted:
		return
	var s := _stream(n)
	if s == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(n, -1000)) < 40:
		return
	_last[n] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_var, pitch_var))
	p.play()

func music(n: String) -> void:
	var s := _stream(n)
	if s == null:
		_music.stop()
		return
	if _music.stream == s and _music.playing:
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	_music.stream = s
	_music.volume_db = music_db
	_music.play()

func stop_music() -> void:
	_music.stop()

## Pause menu / cutscenes: quieter music.
func duck(on: bool) -> void:
	var t := create_tween()
	t.tween_property(_music, "volume_db", music_db - (12.0 if on else 0.0), 0.25)

func toggle_mute() -> void:
	Save.set_muted(not Save.muted)
	_apply_mute()

func _apply_mute() -> void:
	AudioServer.set_bus_mute(0, Save.muted)
