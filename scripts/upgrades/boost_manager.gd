extends Node

signal slots_changed
signal boost_used(boost: BoostData)
signal boost_denied(boost: BoostData)
signal cooldown_started(duration: float)

const BOOSTS_DIR := "res://resources/upgrades/boosts/"
const TEST_BOOST_ID := "FV01"
const SPARE_TIRE_ID := "ST01"
const SLOT_COUNT := 3
const LOADOUT_TABLE := "Loadout"
const MAX_PER_RUN := 5

@export var shared_cooldown := 8.0
@export var sound_slowdown := 0.6
@export var sound_slowdown_rate := 3.0

var active: Array[BoostData] = []
var _time_left: Dictionary = {}
var _boosts: Dictionary = {}
var _run_left: Array[int] = [0, 0, 0]
var _cooldown_left := 0.0
var _locking_boost: BoostData


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_boosts()
	InputController.test_boost.connect(activate_test_boost)
	InputController.boost_slot.connect(use_slot)
	InputController.spare_tire.connect(use_spare_tire)
	Events.run_started.connect(_on_run_started)


func _load_boosts() -> void:
	for file in ResourceLoader.list_directory(BOOSTS_DIR):
		var boost := load(BOOSTS_DIR + file) as BoostData
		if boost:
			_boosts[boost.id] = boost


func get_boost(boost_id: String) -> BoostData:
	return _boosts.get(boost_id)


func get_spare_tire() -> BoostData:
	return get_boost(SPARE_TIRE_ID)

# ============================ INVENTORY =======================================

func boost_for_object(object_id: String) -> BoostData:
	if object_id.is_empty():
		return null
	var row: Dictionary = BaseInventoryManager.find_object_by_id(object_id)
	return get_boost(str(row.get("BoostId", "")))


func object_for_boost(boost: BoostData) -> Dictionary:
	if boost == null:
		return {}
	for row in BaseInventoryManager.get_rows("Objects"):
		if row is Dictionary and str(row.get("BoostId", "")) == boost.id:
			return row
	return {}


func count(boost: BoostData) -> int:
	return int(object_for_boost(boost).get("Quantity", 0))


func is_slot_boost(boost: BoostData) -> bool:
	return boost != null and boost.duration > 0.0

# ============================ LOADOUT =========================================

func get_slot_object_id(slot: int) -> String:
	var row := _loadout_row(slot)
	return str(row.get("ObjectId", "")) if not row.is_empty() else ""


func get_slot_boost(slot: int) -> BoostData:
	return boost_for_object(get_slot_object_id(slot))


func get_slot_count(slot: int) -> int:
	var row := _loadout_row(slot)
	if row.is_empty() or str(row.get("ObjectId", "")).is_empty():
		return 0
	return int(row.get("Count", 0))


func total_loaded() -> int:
	var total := 0
	for i in SLOT_COUNT:
		total += get_slot_count(i)
	return total


func add_to_slot(slot: int, object_id: String) -> bool:
	if slot < 0 or slot >= SLOT_COUNT or not is_slot_boost(boost_for_object(object_id)):
		return false

	var owned := int(BaseInventoryManager.find_object_by_id(object_id).get("Quantity", 0))
	var row := _loadout_row(slot)
	var same := str(row.get("ObjectId", "")) == object_id
	var current := get_slot_count(slot) if same else 0
	var moved := 0
	for i in SLOT_COUNT:
		if i != slot and get_slot_object_id(i) == object_id:
			moved = get_slot_count(i)
	var free := MAX_PER_RUN - total_loaded() + get_slot_count(slot) + moved
	var wanted := current + 1 if same else maxi(moved, 1)
	wanted = mini(wanted, mini(owned, free))
	if wanted <= current:
		return false

	for i in SLOT_COUNT:
		if i != slot and get_slot_object_id(i) == object_id:
			_clear_row(_loadout_row(i))
	row["ObjectId"] = object_id
	row["Count"] = wanted
	_save_loadout()
	return true


func remove_one(slot: int) -> void:
	var row := _loadout_row(slot)
	if row.is_empty() or get_slot_object_id(slot).is_empty():
		return
	row["Count"] = get_slot_count(slot) - 1
	if int(row["Count"]) <= 0:
		_clear_row(row)
	_save_loadout()


func clear_slot(slot: int) -> void:
	var row := _loadout_row(slot)
	if row.is_empty() or get_slot_object_id(slot).is_empty():
		return
	_clear_row(row)
	_save_loadout()


func sanitize_loadout() -> void:
	var changed := false
	for i in SLOT_COUNT:
		var row := _loadout_row(i)
		var object_id := get_slot_object_id(i)
		if object_id.is_empty():
			if int(row.get("Count", 0)) != 0:
				row["Count"] = 0
				changed = true
			continue
		var owned := int(BaseInventoryManager.find_object_by_id(object_id).get("Quantity", 0))
		var count_now := get_slot_count(i)
		var fixed := clampi(count_now, 0, owned)
		if fixed <= 0:
			_clear_row(row)
			changed = true
		elif fixed != count_now:
			row["Count"] = fixed
			changed = true
	while total_loaded() > MAX_PER_RUN:
		for i in range(SLOT_COUNT - 1, -1, -1):
			if get_slot_count(i) > 0 and total_loaded() > MAX_PER_RUN:
				remove_one(i)
		changed = true
	if changed:
		_save_loadout()
	else:
		slots_changed.emit()


func _clear_row(row: Dictionary) -> void:
	row["ObjectId"] = ""
	row["Count"] = 0


func _save_loadout() -> void:
	BaseInventoryManager.save_data()
	slots_changed.emit()


func _loadout_row(slot: int) -> Dictionary:
	var rows: Array = BaseInventoryManager.data.get(LOADOUT_TABLE, [])
	for row in rows:
		if row is Dictionary and int(row.get("ID", 0)) == slot + 1:
			return row
	if slot < 0 or slot >= SLOT_COUNT:
		return {}
	var row := {"ID": slot + 1, "ObjectId": "", "Count": 0}
	rows.append(row)
	BaseInventoryManager.data[LOADOUT_TABLE] = rows
	return row

# ============================ USE =============================================

func _on_run_started() -> void:
	sanitize_loadout()
	_cooldown_left = 0.0
	_locking_boost = null
	for i in SLOT_COUNT:
		_run_left[i] = get_slot_count(i)
	slots_changed.emit()


func run_left(slot: int) -> int:
	return _run_left[slot] if slot >= 0 and slot < SLOT_COUNT else 0


func get_cooldown_left() -> float:
	return _cooldown_left


func is_locked() -> bool:
	return _locking_boost != null or _cooldown_left > 0.0


func get_cooldown_ratio() -> float:
	if _locking_boost != null:
		return 1.0
	return clampf(_cooldown_left / shared_cooldown, 0.0, 1.0) if shared_cooldown > 0.0 else 0.0


func use_slot(slot: int) -> void:
	var boost := get_slot_boost(slot)
	if boost == null or get_tree().paused:
		return
	if run_left(slot) <= 0 or is_locked():
		if GameFlow.in_run:
			boost_denied.emit(boost)
		return
	if use(boost):
		_run_left[slot] -= 1
		_locking_boost = boost


func use_spare_tire() -> void:
	use(get_spare_tire())


func can_use(boost: BoostData) -> bool:
	if boost == null or not GameFlow.in_run or get_tree().paused or active.has(boost) or count(boost) <= 0:
		return false
	for effect in boost.effects:
		if not effect.can_activate():
			return false
	return true


func use(boost: BoostData) -> bool:
	if not can_use(boost):
		if boost and GameFlow.in_run:
			boost_denied.emit(boost)
		return false

	var row := object_for_boost(boost)
	row["Quantity"] = int(row.get("Quantity", 0)) - 1
	BaseInventoryManager.save_data()

	activate(boost)
	boost_used.emit(boost)
	return true


func activate(boost: BoostData) -> void:
	if boost.duration > 0.0:
		if not active.has(boost):
			active.append(boost)
		_time_left[boost] = boost.duration

	for effect in boost.effects:
		effect.on_event(&"boost_activated", {"boost": boost})


func activate_test_boost() -> void:
	if not OS.is_debug_build():
		return
	var boost := get_boost(TEST_BOOST_ID)
	if boost and not active.has(boost):
		activate(boost)


func get_time_left(boost: BoostData) -> float:
	return _time_left.get(boost, 0.0)


func _process(delta: float) -> void:
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	_update_sound_speed(real_delta)

	if get_tree().paused:
		return

	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - real_delta, 0.0)

	for boost in active.duplicate():
		_time_left[boost] -= real_delta

		if _time_left[boost] <= 0.0:
			_expire(boost)


func _update_sound_speed(real_delta: float) -> void:
	var target := 1.0
	if not get_tree().paused and GameFlow.in_run:
		target = lerpf(1.0, Engine.time_scale, sound_slowdown)
	AudioServer.playback_speed_scale = move_toward(
		AudioServer.playback_speed_scale, target, sound_slowdown_rate * real_delta
	)


func clear_active() -> void:
	for boost in active.duplicate():
		_expire(boost)


func _expire(boost: BoostData) -> void:
	active.erase(boost)
	_time_left.erase(boost)

	if boost == _locking_boost:
		_locking_boost = null
		_cooldown_left = shared_cooldown
		cooldown_started.emit(shared_cooldown)

	for effect in boost.effects:
		effect.on_event(&"boost_expired", {"boost": boost})
