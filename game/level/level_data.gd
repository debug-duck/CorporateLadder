class_name LevelData
extends RefCounted
## The one level, as data. PoC scope (owner decision): ONE department, LEVEL_DEPT, over Cfg.FLOORS floors with a
## difficulty ramp, then the CEO rooftop. DEPTS is the library of all five departments (projectiles, patterns,
## jokes) so another department is a one-line change of LEVEL_DEPT.
## patterns: [motion, item, weight, first floor it may appear on]. motion "burst" = three drops in a row down one
## lane ("the full deck"): the lane stays dangerous longer, so the player has to reroute or wait.
## Blocked windows block the two middle rows of their floor in that column; the ledge rows
## (4f and 4f+3) are always free, so there is always a way around.

const DEPTS := [
	{"id": "hr", "name": "HUMAN RESOURCES", "short": "HR", "color": Color("ff6fb5"), "dark": Color("7a2a6a"),
	 "subtitle": "WHERE COMPLAINTS GO TO DIE.", "shout": "WE VALUE YOUR CONTRIBUTION!",
	 "interval": [2.7, 3.7], "max_active": 1, "warn": 1.25, "speed": 0.9,
	 "patterns": [["drop", "paper_stack", 3, 1], ["sweep", "letter", 2, 2], ["lob", "paper_stack", 1, 4]]},
	{"id": "acc", "name": "ACCOUNTING", "short": "ACCOUNTING", "color": Color("5ed37a"), "dark": Color("1f5e34"),
	 "subtitle": "EVERY PENNY COUNTED. NONE FOR YOU.", "shout": "NOT IN THE BUDGET!",
	 "interval": [2.3, 3.2], "max_active": 2, "warn": 1.1, "speed": 1.0,
	 "patterns": [["drop", "calculator", 3, 1], ["lob", "binder", 2, 3], ["sweep", "letter", 1, 2]]},
	{"id": "mgmt", "name": "MANAGEMENT", "short": "MANAGEMENT", "color": Color("4f9dff"), "dark": Color("1d3a7a"),
	 "subtitle": "PRODUCTIVITY IS EVERYONE ELSE'S PROBLEM.", "shout": "LET'S CIRCLE BACK!",
	 "interval": [0.95, 1.4], "max_active": 2, "warn": 1.0, "speed": 1.08,
	 "patterns": [["drop", "bs", 3, 1], ["sweep", "ppt", 2, 3], ["burst", "ppt", 2, 4], ["lob", "bs", 1, 6], ["double", "bs", 1, 9]]},
	{"id": "it", "name": "IT DEPARTMENT", "short": "IT", "color": Color("38e8ff"), "dark": Color("12324a"),
	 "subtitle": "YOUR TICKET IS VERY IMPORTANT TO US.", "shout": "WORKS ON MY MACHINE!",
	 "interval": [1.75, 2.45], "max_active": 2, "warn": 0.95, "speed": 1.15,
	 "patterns": [["drop", "crt", 3, 1], ["split", "keyboard", 2, 3], ["sweep", "keycap", 1, 2]]},
	{"id": "mkt", "name": "MARKETING", "short": "MARKETING", "color": Color("ffb43a"), "dark": Color("7a3a12"),
	 "subtitle": "SYNERGY! DISRUPTION! FREE STICKERS!", "shout": "LET'S MAKE IT VIRAL!",
	 "interval": [1.5, 2.2], "max_active": 3, "warn": 0.9, "speed": 1.22,
	 "patterns": [["drop", "mug", 2, 1], ["double", "mug", 2, 4], ["lob", "tshirt", 2, 2], ["split", "confetti_box", 2, 3], ["sweep", "tshirt", 1, 2]]},
]

const ROOF := {"id": "roof", "name": "EXECUTIVE LEVEL", "short": "CEO", "color": Color("ffd34a"), "dark": Color("6a4a10"),
	"subtitle": "AUTHORIZED EGOS ONLY.", "shout": ""}

## Projectile definitions. motion: drop (falls in its column) | lob (tossed toward a column) | sweep (flies across a row)
## | split (falls, then bursts into two `child` pieces flying to the neighbouring columns: the centre becomes safe).
const PROJECTILES := {
	"letter": {"scale": 0.36, "radius": 30, "speed": 420.0, "wave": 38.0, "spin": 2.5},
	"paper_stack": {"scale": 0.46, "radius": 36, "gravity": 650.0, "vmax": 720.0, "wobble": 14.0, "spin": 0.6},
	"calculator": {"scale": 0.44, "radius": 36, "gravity": 900.0, "vmax": 900.0, "spin": 3.0},
	"binder": {"scale": 0.44, "radius": 38, "gravity": 850.0, "vmax": 880.0, "spin": 4.0},
	"bs": {"scale": 0.44, "radius": 36, "gravity": 950.0, "vmax": 980.0, "wobble": 8.0, "spin": 0.0, "splat": true},
	"ppt": {"scale": 0.44, "radius": 38, "speed": 600.0, "wave": 55.0, "spin": 0.0},
	"crt": {"scale": 0.52, "radius": 44, "gravity": 1150.0, "vmax": 1080.0, "spin": 1.2, "heavy": true},
	"keyboard": {"scale": 0.5, "radius": 38, "gravity": 800.0, "vmax": 800.0, "spin": 1.0, "child": "keycap"},
	"keycap": {"scale": 0.26, "radius": 24, "gravity": 900.0, "vmax": 900.0, "speed": 560.0, "wave": 20.0, "spin": 8.0},
	"mug": {"scale": 0.34, "radius": 28, "gravity": 950.0, "vmax": 950.0, "spin": 5.0},
	"tshirt": {"scale": 0.38, "radius": 32, "gravity": 700.0, "vmax": 760.0, "speed": 560.0, "wave": 30.0, "wobble": 18.0, "spin": 2.0},
	"confetti_box": {"scale": 0.42, "radius": 36, "gravity": 820.0, "vmax": 820.0, "spin": 2.0, "child": "mug", "confetti": true},
}

## floor -> [[col, kind]]   kind: boarded | ac | ficus
const BLOCKERS := {
	1: [[1, "boarded"], [3, "ac"]], 2: [[0, "ficus"], [2, "boarded"], [4, "ac"]], 3: [[1, "ac"], [3, "boarded"]],
	4: [[0, "boarded"], [2, "ficus"], [3, "ac"]], 5: [[1, "boarded"], [4, "ficus"]], 6: [[0, "ac"], [2, "boarded"], [3, "ficus"]],
	7: [[1, "ficus"], [2, "ac"], [4, "boarded"]], 8: [[0, "boarded"], [3, "ac"]], 9: [[1, "ac"], [2, "boarded"], [4, "ficus"]],
	10: [[0, "ficus"], [2, "ac"], [3, "boarded"]], 11: [[1, "boarded"], [3, "ficus"], [4, "ac"]], 12: [[0, "ac"], [2, "boarded"]],
	13: [[1, "ac"], [3, "boarded"], [4, "ficus"]], 14: [[0, "boarded"], [2, "ac"], [3, "ficus"]], 15: [[1, "ficus"], [2, "boarded"], [4, "ac"]],
}

## Promotion badges: [col, row]
const BADGES := [[4, 11], [1, 23], [3, 39], [0, 51]]

## Ledge banners (corporate satire on the cornice bands): floor -> text
const BANNERS := {
	2: "SYNERGY IS NOT A BUZZWORD", 3: "WE'RE A FAMILY*", 4: "*NOT LEGALLY BINDING", 5: "THINK OUTSIDE THE BOX",
	6: "BRING YOUR WHOLE SELF TO WORK", 7: "BUT NOT YOUR FEELINGS", 8: "ONE TEAM ONE DREAM",
	9: "PIZZA FRIDAY = YOUR BONUS", 10: "LEAN IN. THEN LEAN OUT.", 11: "FAIL FAST (NOT YOU)",
	12: "OUR PEOPLE ARE OUR GREATEST ASSET", 13: "ASSETS CAN BE LIQUIDATED", 14: "DISRUPT EVERYTHING",
	15: "UNLIMITED VACATION (DO NOT USE)",
}

const LEVEL_DEPT := "mgmt"

static func level_dept() -> Dictionary:
	for d in DEPTS:
		if d.id == LEVEL_DEPT:
			return d
	return DEPTS[0]

## -1 lobby, 0 the level's department, 1 rooftop
static func dept_index_for_floor(f: int) -> int:
	if f <= 0:
		return -1
	if f > Cfg.FLOORS:
		return 1
	return 0

static func dept(i: int) -> Dictionary:
	return ROOF if i >= 1 else level_dept()

## 0 on the first department floor .. 1 on the last: drives the difficulty ramp.
static func ramp(f: int) -> float:
	return clampf(float(f - 1) / maxf(1.0, Cfg.FLOORS - 1), 0.0, 1.0)

static func is_blocked(c: int, r: int) -> bool:
	var f := r / Cfg.ROWS_PER_FLOOR
	var k := r % Cfg.ROWS_PER_FLOOR
	if k == 0 or k == 3 or not BLOCKERS.has(f):
		return false
	for b in BLOCKERS[f]:
		if int(b[0]) == c:
			return true
	return false

static func blocker_kind(f: int, c: int) -> String:
	for b in BLOCKERS.get(f, []):
		if int(b[0]) == c:
			return String(b[1])
	return ""
