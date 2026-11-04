class_name Projectile
extends Sprite2D
## A thrown office object. motion:
##   drop  - falls straight down its column (gravity, terminal speed, optional wobble)
##   lob   - tossed up and over to a target column, then falls straight
##   sweep - flies horizontally across one row (optional sine wave)
##   split - falls, then bursts at `split_y` into two `child` pieces drifting to the neighbouring columns
## Collision is a circle (`radius`) checked by Run against the player's body circle.

var kind := ""
var motion := "drop"
var radius := 32.0
var vel := Vector2.ZERO
var gravity := 900.0
var vmax := 900.0
var spin := 0.0
var wobble := 0.0
var wave := 0.0
var speed_mult := 1.0
var target_x := 0.0
var lane_x := 0.0
var sweep_y := 0.0
var split_y := INF
var child := ""
var dodge_checked := false
var dead := false
var age := 0.0
var _y0 := 0.0

signal split_now(p: Projectile)

func setup(k: String, mot: String, from: Vector2, mult: float) -> void:
	kind = k
	motion = mot
	var d: Dictionary = LevelData.PROJECTILES[k]
	texture = Art.tex(k)
	scale = Vector2.ONE * float(d.get("scale", 0.4))
	radius = float(d.get("radius", 32))
	gravity = float(d.get("gravity", 900.0)) * mult
	vmax = float(d.get("vmax", 900.0)) * mult
	spin = float(d.get("spin", 0.0)) * (1.0 if randf() < 0.5 else -1.0)
	wobble = float(d.get("wobble", 0.0))
	wave = float(d.get("wave", 0.0))
	child = String(d.get("child", ""))
	speed_mult = mult
	position = from
	lane_x = from.x
	_y0 = from.y
	match motion:
		"drop", "split":
			vel = Vector2(0, 60)
		"lob":
			vel = Vector2(0, -360)
		"drift":
			vel = Vector2(0, 120)
		"sweep":
			vel = Vector2(float(d.get("speed", 450.0)) * mult, 0)

func aim_lob(tx: float) -> void:
	target_x = tx
	vel.x = (tx - position.x) / 0.62

func aim_sweep(dir: float, y: float) -> void:
	vel.x = absf(vel.x) * dir
	sweep_y = y
	flip_h = dir < 0

func aim_drift(tx: float) -> void:
	motion = "drift"
	target_x = tx
	vel = Vector2((tx - position.x) / 0.42, -120)

func _physics_process(delta: float) -> void:
	if dead:
		return
	age += delta
	match motion:
		"drop", "split":
			vel.y = minf(vel.y + gravity * delta, vmax)
			position.y += vel.y * delta
			position.x = lane_x + sin(age * 7.0) * wobble
			if motion == "split" and position.y >= split_y:
				dead = true
				split_now.emit(self)
		"lob", "drift":
			vel.y = minf(vel.y + gravity * delta, vmax)
			position.y += vel.y * delta
			if vel.x != 0.0:
				var nx := position.x + vel.x * delta
				if (vel.x > 0 and nx >= target_x) or (vel.x < 0 and nx <= target_x):
					nx = target_x
					vel.x = 0.0
				position.x = nx
			else:
				position.x = target_x + sin(age * 7.0) * wobble
		"sweep":
			position.x += vel.x * delta
			var k := clampf(age / 0.35, 0.0, 1.0)
			position.y = lerpf(_y0, sweep_y, k * k * (3 - 2 * k)) + sin(age * 6.0) * wave * k
	rotation += spin * delta

## Where a falling projectile will be horizontally at the bottom of its fall (telegraph lane).
func lane() -> float:
	return target_x if motion in ["lob", "drift"] else lane_x
