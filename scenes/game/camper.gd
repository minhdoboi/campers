class_name Camper
extends Sprite2D
## A camper that executes a queue of actions (walks and tasks); the HUD shows
## the queue as a timeline. Campers start idle: the player adds waypoints with
## click and tasks from the HUD menu, or switches the camper to a mode
## (roaming wanders on its own, inspect adds an inspect task after each
## waypoint). When morale drops to 30% they go autonomous and choose their
## own walks, foraging, and view-watching until spirits recover.

signal actions_changed

enum Mode { IDLE, ROAM, INSPECT, AUTONOMOUS }
enum Emotion { ANGRY, NEUTRAL, BORED, HAPPY, SCARED, SAD }

const MODE_NAMES := {
	Mode.IDLE: "Idle",
	Mode.ROAM: "Roaming",
	Mode.INSPECT: "Inspect",
	Mode.AUTONOMOUS: "Autonomous",
}

const EMOTION_NAMES := {
	Emotion.ANGRY: "Angry",
	Emotion.NEUTRAL: "Neutral",
	Emotion.BORED: "Bored",
	Emotion.HAPPY: "Happy",
	Emotion.SCARED: "Scared",
	Emotion.SAD: "Sad",
}

const EMOTION_ICONS := {
	Emotion.ANGRY: "😠",
	Emotion.NEUTRAL: "😐",
	Emotion.BORED: "🥱",
	Emotion.HAPPY: "😄",
	Emotion.SCARED: "😨",
	Emotion.SAD: "😢",
}

const SPEED := 30.0

## Stat rates in points per second; energy and morale both range 0-100.
const ENERGY_WALK_DRAIN := 1.5
const ENERGY_TASK_DRAIN := 1.0
const ENERGY_REST_GAIN := 6.0
const ENERGY_IDLE_GAIN := 2.0
const MORALE_WALK_DRAIN := 0.2
## Morale gained while walking when energy is above the fresh threshold.
const MORALE_WALK_GAIN := 0.5
const MORALE_TASK_DRAIN := 0.4
const MORALE_REST_GAIN := 1.5
const MORALE_VIEW_GAIN := 3.0
## Extra lift while watching the view from elevated ground (level ≥ 1).
const MORALE_VIEW_HIGH_GAIN := 5.5
const MORALE_IDLE_GAIN := 0.3
const MORALE_BORED_DRAIN := 0.8
const MORALE_EXHAUSTED_DRAIN := 1.5
## Morale from wildlife within encounter range.
const MORALE_ANIMAL_GAIN := 1.2
## Instant morale when berries are found while foraging.
const MORALE_BERRY_GAIN := 12.0
## Below this energy the camper is exhausted and morale bleeds away.
const EXHAUSTED_ENERGY := 20.0
## Walking above this energy lifts morale instead of draining it.
const FRESH_WALK_ENERGY := 40.0
## Enter / leave autonomous mode (hysteresis avoids thrashing).
const AUTONOMOUS_ENTER := 30.0
const AUTONOMOUS_EXIT := 40.0
## Seconds without any action before an idle camper turns bored.
const BORED_AFTER := 8.0
## A ground animal within this many world px startles the camper.
const SCARE_RADIUS := 40.0
## Wildlife within this range lifts morale (nature encounter).
const ENCOUNTER_RADIUS := 110.0
## Prefer cells at least this high when autonomously seeking a view.
const HIGH_VIEW_LEVEL := 1
## Instant energy cost to climb a cliff edge up / down one level.
const ENERGY_CLIMB_UP := 30.0
const ENERGY_CLIMB_DOWN := 5.0

## How many actions roaming / autonomous keeps queued up.
const QUEUE_TARGET := 4
const WANDER_RADIUS := 9
const INSPECT_DURATION_MIN := 1.5
const INSPECT_DURATION_MAX := 3.0
## Chance to discover a nearby hidden card, by activity.
const FIND_CHANCE_INSPECT := 0.8
const FIND_CHANCE_ROAM := 0.5
const FIND_CHANCE_MOVE := 0.2

## [label, min duration, max duration]
const TASKS := [
	["Rest", 2.0, 4.0],
	["Gather wood", 2.0, 3.5],
	["Forage berries", 1.5, 3.0],
	["Watch the view", 2.0, 4.5],
	["Tend the fire", 1.5, 3.0],
]

## Tasks an autonomous camper may choose after (or instead of) roaming.
const AUTONOMOUS_TASKS := [
	["Forage berries", 1.5, 3.0],
	["Watch the view", 2.0, 4.5],
]

## The tool each role carries, shown in the camper's backpack.
const ROLE_ITEMS := {
	"Photographer": {"icon": "📷", "name": "Camera"},
	"Botanist": {"icon": "🔍", "name": "Magnifying glass"},
	"Tracker": {"icon": "🧭", "name": "Compass"},
	"Ornithologist": {"icon": "🔭", "name": "Binoculars"},
	"Activist": {"icon": "📣", "name": "Megaphone"},
	"Hydrologist": {"icon": "🧪", "name": "Test tube"},
	"Journalist": {"icon": "📱", "name": "Smartphone"},
}

var game: Node2D
var cell: Vector2i
var display_name := "Camper"
var portrait: Texture2D
## 1-2 roles assigned at spawn, e.g. ["Botanist", "Tracker"].
var roles: Array[String] = []
## Tools carried, derived from roles at setup; each {"icon": String, "name": String}.
var inventory: Array[Dictionary] = []
var mode: Mode = Mode.IDLE
var energy := 100.0
var morale := 75.0
var emotion: Emotion = Emotion.NEUTRAL
## Queue of {"type": "walk"|"task"|"climb", "label": String, ...}; index 0 is current.
## Roam/autonomous-generated entries carry "auto": true so they can be dropped
## when the camper leaves those modes.
var actions: Array[Dictionary] = []

var _path: Array = []
var _timer := 0.0
var _idle_time := 0.0
var _current_started := false
var _plan_cell: Vector2i # where the camper will stand once the queue is done


## Cell the camper will occupy after finishing the current action queue.
func plan_cell() -> Vector2i:
	return _plan_cell


func setup(game_node: Node2D, start_cell: Vector2i, camper_name: String, color: Color,
		camper_portrait: Texture2D, camper_roles: Array[String]) -> void:
	game = game_node
	cell = start_cell
	_plan_cell = start_cell
	display_name = camper_name
	portrait = camper_portrait
	roles = camper_roles
	energy = randf_range(70.0, 100.0)
	morale = randf_range(55.0, 90.0)
	modulate = color
	position = game.cell_to_world(cell)
	inventory.clear()
	for role in roles:
		if ROLE_ITEMS.has(role):
			inventory.append(ROLE_ITEMS[role])


func _process(delta: float) -> void:
	if game == null or game.paused:
		return
	if mode == Mode.ROAM or mode == Mode.AUTONOMOUS:
		while actions.size() < QUEUE_TARGET:
			if mode == Mode.AUTONOMOUS:
				_append_autonomous_plan()
			else:
				_append_plan()
	_update_stats(delta)
	if actions.is_empty():
		return
	if not _current_started:
		_start_current()
		return
	var action := actions[0]
	if action.type == "walk" or action.type == "climb":
		_process_walk(delta)
	else:
		_timer -= delta
		if _timer <= 0.0:
			_finish_current()


## Queues a walk to the given cell; in inspect mode, an inspect task is
## queued right after it. Ignored when the cell is unreachable.
func add_waypoint(target: Vector2i) -> void:
	if target == _plan_cell or game.find_path(_plan_cell, target).is_empty():
		return
	actions.append(_walk_action(_plan_cell, target))
	_plan_cell = target
	if mode == Mode.INSPECT:
		actions.append(_inspect_action())
	actions_changed.emit()


## Queues a one-cell cliff climb/descend to an adjacent tile at a different
## level. Energy is spent when the action starts (not when queued), so climbs
## can be planned after a walk or rest. Returns false if the target is invalid.
func add_climb(target: Vector2i) -> bool:
	if not _can_climb(_plan_cell, target):
		return false
	var going_up: bool = game.level_at(target) > game.level_at(_plan_cell)
	var cost := ENERGY_CLIMB_UP if going_up else ENERGY_CLIMB_DOWN
	var verb := tr("Climb up") if going_up else tr("Climb down")
	actions.append({
		"type": "climb",
		"target": target,
		"energy_cost": cost,
		"label": "%s (%d, %d)" % [verb, target.x, target.y],
	})
	_plan_cell = target
	actions_changed.emit()
	return true


## Whether `from` can cliff-climb to orthogonal neighbour `to` (level ±1,
## walkable, and not already connected by a ramp).
func _can_climb(from: Vector2i, to: Vector2i) -> bool:
	return game.can_cliff_climb(from, to)


func add_task(label: String, duration_min: float, duration_max: float) -> void:
	actions.append({
		"type": "task",
		"label": label,
		"duration": randf_range(duration_min, duration_max),
	})
	actions_changed.emit()


func remove_action(index: int) -> void:
	if index < 0 or index >= actions.size():
		return
	if index == 0 and _current_started:
		_path.clear()
		_current_started = false
	actions.remove_at(index)
	_recompute_plan_cell()
	actions_changed.emit()


func set_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	if not _is_self_directed():
		_clear_auto_actions()
	actions_changed.emit()


func _is_self_directed() -> bool:
	return mode == Mode.ROAM or mode == Mode.AUTONOMOUS


## Advances energy and morale from the current activity, then rederives the
## emotion. Walking drains energy; morale rises while energy stays above 40%
## and drains when tired. Most tasks drain both stats; resting restores them,
## watching the view lifts morale (more from high ground), wildlife nearby
## lifts morale, and sitting idle slowly recovers energy — until boredom sets
## in. Low morale triggers autonomous mode.
func _update_stats(delta: float) -> void:
	var energy_rate := ENERGY_IDLE_GAIN
	var morale_rate := MORALE_IDLE_GAIN
	if actions.is_empty():
		_idle_time += delta
		if _idle_time >= BORED_AFTER:
			morale_rate = -MORALE_BORED_DRAIN
	else:
		_idle_time = 0.0
		var action := actions[0]
		if action.type == "walk" or action.type == "climb":
			energy_rate = -ENERGY_WALK_DRAIN
			morale_rate = MORALE_WALK_GAIN if energy > FRESH_WALK_ENERGY else -MORALE_WALK_DRAIN
		else:
			match action.label:
				"Rest":
					energy_rate = ENERGY_REST_GAIN
					morale_rate = MORALE_REST_GAIN
				"Watch the view":
					energy_rate = -ENERGY_TASK_DRAIN * 0.3
					morale_rate = MORALE_VIEW_HIGH_GAIN if game.level_at(cell) >= HIGH_VIEW_LEVEL \
							else MORALE_VIEW_GAIN
				_:
					energy_rate = -ENERGY_TASK_DRAIN
					morale_rate = -MORALE_TASK_DRAIN
	if _animal_in_encounter_range():
		morale_rate += MORALE_ANIMAL_GAIN
	if energy < EXHAUSTED_ENERGY:
		morale_rate -= MORALE_EXHAUSTED_DRAIN
	energy = clampf(energy + energy_rate * delta, 0.0, 100.0)
	morale = clampf(morale + morale_rate * delta, 0.0, 100.0)
	emotion = _derive_emotion()
	_update_autonomous_mode()


func _update_autonomous_mode() -> void:
	if morale <= AUTONOMOUS_ENTER and mode != Mode.AUTONOMOUS:
		set_mode(Mode.AUTONOMOUS)
	elif morale > AUTONOMOUS_EXIT and mode == Mode.AUTONOMOUS:
		set_mode(Mode.IDLE)


func _derive_emotion() -> Emotion:
	if _animal_nearby():
		return Emotion.SCARED
	if morale < 25.0:
		return Emotion.ANGRY if energy >= 35.0 else Emotion.SAD
	if morale >= 75.0 and energy >= 40.0:
		return Emotion.HAPPY
	if _idle_time >= BORED_AFTER:
		return Emotion.BORED
	return Emotion.NEUTRAL


func _animal_nearby() -> bool:
	return _nearest_animal_distance() < SCARE_RADIUS


func _animal_in_encounter_range() -> bool:
	return _nearest_animal_distance() < ENCOUNTER_RADIUS


func _nearest_animal_distance() -> float:
	var nearest := INF
	for animal in game.animals:
		if not is_instance_valid(animal):
			continue
		nearest = minf(nearest, animal.position.distance_to(position))
	return nearest


func _process_walk(delta: float) -> void:
	if _path.is_empty():
		_finish_current()
		return
	var target: Vector2 = game.cell_to_world(_path[0])
	if absf(target.x - position.x) > 0.5:
		flip_h = target.x < position.x
	position = position.move_toward(target, SPEED * delta)
	if position.distance_to(target) < 0.5:
		cell = _path.pop_front()
		game.reveal_around(cell)


func _start_current() -> void:
	if actions.is_empty():
		return
	var action := actions[0]
	_current_started = true
	if action.type == "walk":
		_path = game.find_path(cell, action.target)
		if _path.is_empty():
			_finish_current()
			return
	elif action.type == "climb":
		var cost: float = action.get("energy_cost", ENERGY_CLIMB_UP)
		if energy < cost or not _can_climb(cell, action.target):
			_finish_current()
			return
		energy = clampf(energy - cost, 0.0, 100.0)
		_path = [action.target]
	else:
		_timer = action.duration
	actions_changed.emit()


func _finish_current() -> void:
	var finished: Dictionary = actions[0]
	actions.pop_front()
	_current_started = false
	if finished.type == "task":
		var label := str(finished.label)
		if label.begins_with("Inspect"):
			_try_collect_nearby_cards(FIND_CHANCE_INSPECT)
		elif label == "Forage berries":
			_try_find_berries()
	elif finished.type == "walk" or finished.type == "climb":
		var chance := FIND_CHANCE_MOVE
		if mode == Mode.ROAM or mode == Mode.AUTONOMOUS:
			chance = FIND_CHANCE_ROAM
		_try_collect_nearby_cards(chance)
	_recompute_plan_cell()
	actions_changed.emit()


## Roll `chance` to pick up any hidden evidence cards on this cell or an
## adjacent one into the team's card collection.
func _try_collect_nearby_cards(chance: float) -> void:
	if randf() >= chance:
		return
	var finds: Array[Dictionary] = game.try_discover_nearby(cell, roles)
	if finds.is_empty():
		return
	morale = clampf(morale + 6.0 * float(finds.size()), 0.0, 100.0)
	emotion = _derive_emotion()
	for find in finds:
		game.log_journal_find(find.item, display_name, find.cell)


## Pick a nearby berry patch (if any): add it to inventory, remove it from
## the map, boost morale, and write a journal entry.
func _try_find_berries() -> void:
	var picked: Dictionary = game.try_forage_berries(cell)
	if picked.is_empty():
		return
	var item: Dictionary = picked.item
	var berry_cell: Vector2i = picked.cell
	inventory.append(item)
	morale = clampf(morale + MORALE_BERRY_GAIN, 0.0, 100.0)
	emotion = _derive_emotion()
	game.log_journal_find(item, display_name, berry_cell)
	game.show_find_toast(position, DiscoverableCards.localize(item).name)


func _walk_action(from: Vector2i, target: Vector2i) -> Dictionary:
	var verb := tr("Walk to")
	if game.level_at(target) > game.level_at(from):
		verb = tr("Climb to")
	elif game.level_at(target) < game.level_at(from):
		verb = tr("Descend to")
	return {
		"type": "walk",
		"target": target,
		"label": "%s (%d, %d)" % [verb, target.x, target.y],
	}


func _inspect_action() -> Dictionary:
	return {
		"type": "task",
		"label": "Inspect",
		"duration": randf_range(INSPECT_DURATION_MIN, INSPECT_DURATION_MAX),
	}


func _append_plan() -> void:
	var target := _pick_wander_target(false)
	if target.x >= 0:
		var walk := _walk_action(_plan_cell, target)
		walk.auto = true
		actions.append(walk)
		_plan_cell = target
	var task: Array = TASKS.pick_random()
	actions.append({
		"type": "task",
		"label": task[0],
		"duration": randf_range(task[1], task[2]),
		"auto": true,
	})
	actions_changed.emit()


## Autonomous campers only roam, forage berries, or watch the view — often
## climbing first when they want a vista.
func _append_autonomous_plan() -> void:
	var roll := randf()
	var prefer_high := roll >= 0.7
	var target := _pick_wander_target(prefer_high)
	if target.x >= 0:
		var walk := _walk_action(_plan_cell, target)
		walk.auto = true
		actions.append(walk)
		_plan_cell = target
	if roll < 0.35:
		# Roam-only: if no walk was possible, forage in place so the queue
		# still advances.
		if target.x < 0:
			var forage: Array = AUTONOMOUS_TASKS[0]
			actions.append({
				"type": "task",
				"label": forage[0],
				"duration": randf_range(forage[1], forage[2]),
				"auto": true,
			})
	elif roll < 0.7:
		var forage: Array = AUTONOMOUS_TASKS[0]
		actions.append({
			"type": "task",
			"label": forage[0],
			"duration": randf_range(forage[1], forage[2]),
			"auto": true,
		})
	else:
		var view: Array = AUTONOMOUS_TASKS[1]
		actions.append({
			"type": "task",
			"label": view[0],
			"duration": randf_range(view[1], view[2]),
			"auto": true,
		})
	actions_changed.emit()


func _pick_wander_target(prefer_high: bool) -> Vector2i:
	var fallback := Vector2i(-1, -1)
	for attempt in 8:
		var candidate: Vector2i = game.random_cell_near(_plan_cell, WANDER_RADIUS)
		if candidate == _plan_cell or game.find_path(_plan_cell, candidate).is_empty():
			continue
		if prefer_high and game.level_at(candidate) < HIGH_VIEW_LEVEL:
			if fallback.x < 0:
				fallback = candidate
			continue
		return candidate
	return fallback


func _clear_auto_actions() -> void:
	if not actions.is_empty() and actions[0].get("auto", false) and _current_started:
		_path.clear()
		_current_started = false
	for i in range(actions.size() - 1, -1, -1):
		if actions[i].get("auto", false):
			actions.remove_at(i)
	_recompute_plan_cell()


func _recompute_plan_cell() -> void:
	_plan_cell = cell
	for action in actions:
		if action.type == "walk" or action.type == "climb":
			_plan_cell = action.target
