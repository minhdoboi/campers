class_name Camper
extends Sprite2D
## A camper that executes a queue of actions (walks and tasks); the HUD shows
## the queue as a timeline. Campers start idle: the player adds waypoints with
## shift+click and tasks from the HUD menu, or switches the camper to a mode
## (roaming wanders on its own, inspect modes add an inspect task after each
## waypoint).

signal actions_changed

enum Mode { IDLE, ROAM, INSPECT_GROUND, INSPECT_TREE }
enum Emotion { ANGRY, NEUTRAL, BORED, HAPPY, SCARED, SAD }

const MODE_NAMES := {
	Mode.IDLE: "Idle",
	Mode.ROAM: "Roaming",
	Mode.INSPECT_GROUND: "Inspect ground",
	Mode.INSPECT_TREE: "Inspect trees",
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
const MORALE_TASK_DRAIN := 0.4
const MORALE_REST_GAIN := 1.5
const MORALE_VIEW_GAIN := 3.0
const MORALE_IDLE_GAIN := 0.3
const MORALE_BORED_DRAIN := 0.8
const MORALE_EXHAUSTED_DRAIN := 1.5
## Below this energy the camper is exhausted and morale bleeds away.
const EXHAUSTED_ENERGY := 20.0
## Seconds without any action before an idle camper turns bored.
const BORED_AFTER := 8.0
## A ground animal within this many world px startles the camper.
const SCARE_RADIUS := 40.0

## How many actions roaming keeps queued up.
const QUEUE_TARGET := 4
const WANDER_RADIUS := 9
const INSPECT_DURATION_MIN := 1.5
const INSPECT_DURATION_MAX := 3.0

## [label, min duration, max duration]
const TASKS := [
	["Rest", 2.0, 4.0],
	["Gather wood", 2.0, 3.5],
	["Forage berries", 1.5, 3.0],
	["Watch the view", 2.0, 4.5],
	["Tend the fire", 1.5, 3.0],
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
## Queue of {"type": "walk"|"task", "label": String, ...}; index 0 is current.
## Roam-generated entries carry "auto": true so they can be dropped when the
## camper leaves roaming mode.
var actions: Array[Dictionary] = []

var _path: Array = []
var _timer := 0.0
var _idle_time := 0.0
var _current_started := false
var _plan_cell: Vector2i # where the camper will stand once the queue is done


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
	if mode == Mode.ROAM:
		while actions.size() < QUEUE_TARGET:
			_append_plan()
	_update_stats(delta)
	if actions.is_empty():
		return
	if not _current_started:
		_start_current()
		return
	var action := actions[0]
	if action.type == "walk":
		_process_walk(delta)
	else:
		_timer -= delta
		if _timer <= 0.0:
			_finish_current()


## Queues a walk to the given cell; in an inspect mode, an inspect task is
## queued right after it. Ignored when the cell is unreachable.
func add_waypoint(target: Vector2i) -> void:
	if target == _plan_cell or game.find_path(_plan_cell, target).is_empty():
		return
	actions.append(_walk_action(_plan_cell, target))
	_plan_cell = target
	match mode:
		Mode.INSPECT_GROUND:
			actions.append(_inspect_action("Inspect ground"))
		Mode.INSPECT_TREE:
			actions.append(_inspect_action("Inspect tree"))
	actions_changed.emit()


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
	if mode != Mode.ROAM:
		_clear_auto_actions()
	actions_changed.emit()


## Advances energy and morale from the current activity, then rederives the
## emotion. Walking and most tasks drain both stats; resting restores them,
## watching the view lifts morale, and sitting idle slowly recovers energy —
## until boredom sets in.
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
		if action.type == "walk":
			energy_rate = -ENERGY_WALK_DRAIN
			morale_rate = -MORALE_WALK_DRAIN
		else:
			match action.label:
				"Rest":
					energy_rate = ENERGY_REST_GAIN
					morale_rate = MORALE_REST_GAIN
				"Watch the view":
					energy_rate = -ENERGY_TASK_DRAIN * 0.3
					morale_rate = MORALE_VIEW_GAIN
				_:
					energy_rate = -ENERGY_TASK_DRAIN
					morale_rate = -MORALE_TASK_DRAIN
	if energy < EXHAUSTED_ENERGY:
		morale_rate -= MORALE_EXHAUSTED_DRAIN
	energy = clampf(energy + energy_rate * delta, 0.0, 100.0)
	morale = clampf(morale + morale_rate * delta, 0.0, 100.0)
	emotion = _derive_emotion()


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
	for animal in game.animals:
		if is_instance_valid(animal) \
				and animal.position.distance_to(position) < SCARE_RADIUS:
			return true
	return false


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
	else:
		_timer = action.duration
	actions_changed.emit()


func _finish_current() -> void:
	var finished: Dictionary = actions[0]
	actions.pop_front()
	_current_started = false
	if finished.type == "task" and str(finished.label).begins_with("Inspect"):
		_collect_nearby_cards()
	_recompute_plan_cell()
	actions_changed.emit()


## Inspect ground/trees: pick up any hidden evidence cards on this cell or
## an adjacent one into the team's card collection.
func _collect_nearby_cards() -> void:
	var cards: Array[Dictionary] = game.try_discover_nearby(cell)
	if cards.is_empty():
		return
	morale = clampf(morale + 6.0 * float(cards.size()), 0.0, 100.0)
	emotion = _derive_emotion()


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


func _inspect_action(label: String) -> Dictionary:
	return {
		"type": "task",
		"label": label,
		"duration": randf_range(INSPECT_DURATION_MIN, INSPECT_DURATION_MAX),
	}


func _append_plan() -> void:
	var target := Vector2i(-1, -1)
	for attempt in 5:
		var candidate: Vector2i = game.random_cell_near(_plan_cell, WANDER_RADIUS)
		if candidate != _plan_cell and not game.find_path(_plan_cell, candidate).is_empty():
			target = candidate
			break
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
		if action.type == "walk":
			_plan_cell = action.target
