# @file: unit_manager.gd
# @brief: 单位管理器，负责处理单位的生成和管理
# @author: ponywu
# @date: 2025-04-21

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

# 生成单位
func spawn_unit(unit_type: String, spawn_position: Vector2) -> void:
	if not UNIT_SCENES.has(unit_type):
		push_error("未知的单位类型：" + unit_type)
		return

	var scene_path = UNIT_SCENES[unit_type]
	var unit_scene = load(scene_path)

	if unit_scene:
		var unit = unit_scene.instantiate()
		unit.global_position = spawn_position
		get_tree().get_root().add_child(unit)
		print("生成单位：", unit_type)
	else:
		push_error("无法加载单位场景：" + scene_path)