class_name LevelData
extends RefCounted
## The one level, as data: CORPORATE HQ = lobby + five departments x FLOORS_PER_DEPT floors (LEVEL_DEPTS, bottom to top)
## + the CEO rooftop. Each department brings its own office colours, throwers, projectiles, patterns and catchphrase;
## a global ramp over all floors (HazardDirector) makes the whole tower gradually harder.
## patterns: [motion, item, weight, first floor INSIDE the department (1..3) it may appear on]. motion "burst" = three
## drops in a row down one lane ("the full deck"): the lane stays dangerous longer, so the player has to reroute or wait.
## Blocked windows block the two middle rows of their floor in that column; the ledge rows
## (4f and 4f+3) are always free, so there is always a way around.

const DEPTS := [
	{"id": "hr", "name": "HUMAN RESOURCES", "short": "HR", "color": Color("ff6fb5"), "dark": Color("7a2a6a"),
	 "subtitle": "WHERE COMPLAINTS GO TO DIE.", "shout": "WE VALUE YOUR CONTRIBUTION!",
	 "interval": [1.3, 1.8], "max_active": 1, "warn": 1.2, "speed": 0.92,
	 "patterns": [["drop", "paper_stack", 3, 1], ["sweep", "letter", 2, 2], ["lob", "paper_stack", 1, 3]]},
	{"id": "acc", "name": "ACCOUNTING", "short": "ACCOUNTING", "color": Color("5ed37a"), "dark": Color("1f5e34"),
	 "subtitle": "EVERY PENNY COUNTED. NONE FOR YOU.", "shout": "NOT IN THE BUDGET!",
	 "interval": [1.1, 1.6], "max_active": 2, "warn": 1.1, "speed": 1.0,
	 "patterns": [["drop", "calculator", 3, 1], ["lob", "binder", 2, 2], ["sweep", "letter", 1, 2], ["burst", "calculator", 1, 3]]},
	{"id": "mgmt", "name": "MANAGEMENT", "short": "MANAGEMENT", "color": Color("4f9dff"), "dark": Color("1d3a7a"),
	 "subtitle": "PRODUCTIVITY IS EVERYONE ELSE'S PROBLEM.", "shout": "LET'S CIRCLE BACK!",
	 "interval": [1.0, 1.45], "max_active": 2, "warn": 1.0, "speed": 1.04,
	 "patterns": [["drop", "bs", 3, 1], ["sweep", "ppt", 2, 1], ["burst", "ppt", 2, 2], ["lob", "bs", 1, 2], ["double", "bs", 1, 3]]},
	{"id": "it", "name": "IT DEPARTMENT", "short": "IT", "color": Color("38e8ff"), "dark": Color("12324a"),
	 "subtitle": "YOUR TICKET IS VERY IMPORTANT TO US.", "shout": "WORKS ON MY MACHINE!",
	 "interval": [0.95, 1.4], "max_active": 3, "warn": 0.95, "speed": 1.08,
	 "patterns": [["drop", "crt", 3, 1], ["split", "keyboard", 2, 1], ["sweep", "keycap", 1, 2], ["double", "crt", 1, 3]]},
	{"id": "mkt", "name": "MARKETING", "short": "MARKETING", "color": Color("ffb43a"), "dark": Color("7a3a12"),
	 "subtitle": "SYNERGY! DISRUPTION! FREE STICKERS!", "shout": "LET'S MAKE IT VIRAL!",
	 "interval": [0.9, 1.35], "max_active": 3, "warn": 0.92, "speed": 1.12,
	 "patterns": [["drop", "mug", 2, 1], ["double", "mug", 2, 1], ["lob", "tshirt", 2, 2], ["split", "confetti_box", 2, 2], ["sweep", "tshirt", 1, 2], ["burst", "mug", 1, 3]]},
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
	1: "PEOPLE FIRST (PROFITS FIRSTER)", 2: "WE'RE A FAMILY*", 3: "*NOT LEGALLY BINDING", 4: "EVERY CENT COUNTS",
	7: "LEADERSHIP IS A JOURNEY", 10: "IT: IT'S ALWAYS DNS", 13: "BRAND IS A FEELING",
	5: "PIZZA FRIDAY = YOUR BONUS", 6: "COST CENTRE OF THE MONTH: YOU",
	8: "SYNERGY IS NOT A BUZZWORD", 9: "THINK OUTSIDE THE BOX",
	11: "HAVE YOU TRIED RESTARTING?", 12: "PASSWORD MUST CONTAIN A SONNET",
	14: "DISRUPT EVERYTHING", 15: "UNLIMITED VACATION (DO NOT USE)",
}

## Bottom to top. Floors 1-3 = first entry, 4-6 = second, ...
const LEVEL_DEPTS := ["hr", "acc", "mgmt", "it", "mkt"]
const FLOORS_PER_DEPT := 3

static func _by_id(id: String) -> Dictionary:
	for d in DEPTS:
		if d.id == id:
			return d
	return DEPTS[0]

## -1 lobby, 0..4 department, 5 rooftop
static func dept_index_for_floor(f: int) -> int:
	if f <= 0:
		return -1
	if f > Cfg.FLOORS:
		return LEVEL_DEPTS.size()
	return mini((f - 1) / FLOORS_PER_DEPT, LEVEL_DEPTS.size() - 1)

static func dept(i: int) -> Dictionary:
	if i >= LEVEL_DEPTS.size():
		return ROOF
	return _by_id(LEVEL_DEPTS[maxi(i, 0)])

## 1..FLOORS_PER_DEPT: which floor of its department floor f is.
static func floor_in_dept(f: int) -> int:
	return (maxi(f, 1) - 1) % FLOORS_PER_DEPT + 1

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
