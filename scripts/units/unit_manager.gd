# @file: unit_manager.gd
# @brief: 单位管理器，负责处理单位的生成和管理
# @author: ponywu
# @date: 2025-05-02

class_name UnitManager
extends Node

# 单例实例
static var instance: UnitManager = null

# 单位场景路径
const UNIT_SCENES = {
	"Worker": "res://scenes/npc/worker.tscn",
	"Knight": "res://scenes/npc/knight.tscn",
	"Archer": "res://scenes/npc/archer.tscn"
}

# 生成单位
var unit_pools = {}  # 按单位类型存储对象池

# 获取单例实例
static func get_instance() -> UnitManager:
	if instance == null:
		instance = UnitManager.new()

		# 确保添加到场景树中
		if Engine.is_editor_hint():
			return instance

		var scene_tree = Engine.get_main_loop()
		if scene_tree and scene_tree is SceneTree:
			scene_tree.root.call_deferred("add_child", instance)
			print("UnitManager 单例已添加到场景树")
	return instance

# 初始化对象池
func _ready() -> void:
	# 在本例中不需要调用父类的 _ready()，因为 Node 基类不需要调用 super

	# 为每种单位类型创建对象池
	for unit_type in UNIT_SCENES:
		unit_pools[unit_type] = []

# 从对象池获取单位
func get_unit_from_pool(unit_type: String) -> Node:
	if not unit_pools.has(unit_type):
		push_error("未知的单位类型：" + unit_type)
		return null

	# 检查池中是否有可用对象
	var pool = unit_pools[unit_type]
	for i in range(pool.size()):
		var unit = pool[i]
		if is_instance_valid(unit) and not unit.is_inside_tree():
			pool.remove_at(i)
			return unit

	# 如果没有可用对象，创建新的
	if not UNIT_SCENES.has(unit_type):
		push_error("未知的单位类型：" + unit_type)
		return null

	var scene_path = UNIT_SCENES[unit_type]
	var unit_scene = load(scene_path)

	if unit_scene:
		return unit_scene.instantiate()
	else:
		push_error("无法加载单位场景：" + scene_path)
		return null

# 生成单位
func spawn_unit(unit_type: String, spawn_position: Vector2) -> void:
	# 获取资源管理器
	var resource_manager = GlobalResourceManager.get_instance()

	# 检查资源是否足够
	if not resource_manager.try_produce_unit(unit_type):
		print("资源不足，无法生成单位：", unit_type)
		return

	# 从对象池获取单位
	var unit = get_unit_from_pool(unit_type)

	if unit:
		unit.global_position = spawn_position
		get_tree().get_root().add_child(unit)
		print("从对象池生成单位：", unit_type)

# 回收单位到对象池
func recycle_unit(unit: Node, unit_type: String) -> void:
	if not unit_pools.has(unit_type):
		push_error("未知的单位类型：" + unit_type)
		return

	if unit.is_inside_tree():
		unit.get_parent().remove_child(unit)

	# 重置单位状态
	if unit.has_method("reset"):
		unit.reset()

	# 将单位放回对象池
	unit_pools[unit_type].append(unit)
	print("回收单位到对象池：", unit_type)
