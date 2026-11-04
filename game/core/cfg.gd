class_name Cfg
extends RefCounted
## Grid + tuning constants. World space: x right, y DOWN (Godot); the street is at y = STREET_Y and the
## building grows upward into negative y. A "row" is one handhold line; 4 rows make one floor.

const W := 1080.0
const H := 1920.0
const COLS := 5
const COL_W := 180.0
const CENTER_X := 540.0
const ROW_H := 100.0
const ROWS_PER_FLOOR := 4
const FLOORS := 15                       # department floors 1..15 (floor 0 = lobby); PoC = ONE department
const TOP_ROW := (FLOORS + 1) * ROWS_PER_FLOOR   # row 64 = rooftop parapet = victory
const FLOOR_H := ROW_H * ROWS_PER_FLOOR
const STREET_Y := 190.0
const FACADE_L := 66.0
const FACADE_R := 1014.0

const START_LIVES := 3
const MOVE_UP_TIME := 0.4
const MOVE_DOWN_TIME := 0.24
const MOVE_SIDE_TIME := 0.19
const INVULN_TIME := 2.0
const STUN_TIME := 0.45
const PROMO_TIME := 10.0
const PLAYER_RADIUS := 34.0
const BODY_OFFSET := Vector2(0, 92)      # grip point (hands) -> body centre

const SCORE_ROW := 10
const SCORE_FLOOR := 100
const SCORE_DODGE := 25
const SCORE_BADGE := 500
const SCORE_ROOF := 5000
const SCORE_LIFE := 1500

static func col_x(c: int) -> float:
	return CENTER_X + (c - 2) * COL_W

static func row_y(r: int) -> float:
	return -r * ROW_H

static func floor_of_row(r: int) -> int:
	return clampi(r / ROWS_PER_FLOOR, 0, FLOORS + 1)

static func floor_base_y(f: int) -> float:
	return -f * FLOOR_H

## Window centre of floor f (the window spans rows 4f+1 .. 4f+2 visually).
static func window_pos(f: int, c: int) -> Vector2:
	return Vector2(col_x(c), floor_base_y(f) - 190.0)

static func cell_pos(c: int, r: int) -> Vector2:
	return Vector2(col_x(c), row_y(r))
