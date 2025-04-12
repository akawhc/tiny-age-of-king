# file: building_manager.gd
# author: ponywu
# date: 2024-03-24
# description: 建筑管理器单例，负责处理所有建筑相关的操作

class_name BuildingManager

extends Node

# 单例实例
static var instance: BuildingManager = null

# 建筑操作信号
signal building_started(type: String)
signal building_completed(type: String)
signal building_cancelled(type: String)

func _init() -> void:
	if instance != null:
		push_error("BuildingManager 已经存在实例")
		return
	instance = self

# 获取单例实例
static func get_instance() -> BuildingManager:
	if instance == null:
		instance = BuildingManager.new()
	return instance

# 处理建造请求
func handle_build_request(action: String, workers: Array) -> void:
	if workers.is_empty():
		print("没有工人被选中，无法开始建造")
		return

	match action:
		"build_castle":
			start_castle_construction(workers)
		"build_house":
			start_house_construction(workers)
		"build_tower":
			start_tower_construction(workers)
		"repair":
			start_repair(workers)

# 开始建造城堡
func start_castle_construction(workers: Array) -> void:
	if workers.is_empty():
		return

	# 让第一个工人开始建造（它会通知其他工人）
	workers[0].build_castle()
	building_started.emit("build_castle")

# 开始建造房屋
func start_house_construction(workers: Array) -> void:
	if workers.is_empty():
		return

	workers[0].build_house()
	building_started.emit("build_house")

# 开始建造箭塔
func start_tower_construction(workers: Array) -> void:
	if workers.is_empty():
		return

	workers[0].build_tower()
	building_started.emit("build_tower")

# 开始修理
func start_repair(workers: Array) -> void:
	if workers.is_empty():
		return

	workers[0].repair()
	building_started.emit("repair")
