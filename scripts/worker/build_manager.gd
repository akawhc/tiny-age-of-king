# @file: build_manager.gd
# @brief: 工人建造管理器组件
# @author: ponywu
# @date: 2025-04-13

extends Node

# 建造状态 - 每个工人只能同时建造一个建筑
var is_building = false
var current_building_target = null  # 当前正在建造的建筑对象

# 建造参数
const BUILD_DISTANCE = 50.0  # 工人与建筑中心的距离
const BUILD_SPEED = 0.1  # 每次敲击增加的建造进度
const BUILD_INTERVAL = 1.0  # 建造动作间隔(秒)

# 建造目标信息
var target_position = Vector2.ZERO  # 工人的目标位置
var last_build_time = 0.0

# 父节点引用
var worker = null
var animated_sprite = null

# 建造完成信号
signal building_completed(building_type, position)

# 初始化
func init(worker_node, animated_sprite_node) -> void:
	worker = worker_node
	animated_sprite = animated_sprite_node

	# 确保默认状态
	is_building = false
	current_building_target = null

# 建造检查
func can_build() -> bool:
	# 检查是否已经在建造
	if is_building:
		return false

	# 检查工人是否携带材料（可以根据需要添加）
	# if worker.wood_manager.is_carrying:
	#    return false

	return true

# 开始建造
func start_building(pos: Vector2, building_type: String) -> void:
	if not can_build():
		print("工人无法开始建造")
		return

	# 计算工人的目标位置（建筑周围的位置）
	var angle = randf() * TAU  # 随机角度，让工人分散开
	var offset = Vector2(cos(angle), sin(angle)) * BUILD_DISTANCE
	target_position = pos + offset

	# 移动到建造位置
	worker.move_to(target_position)

	# 设置建造状态
	is_building = true

	# 获取或创建建筑目标
	var site_manager = get_site_manager()
	current_building_target = site_manager.register_building_site(pos, building_type, worker)

	print("工人开始建造 ", building_type, "，目标位置: ", target_position)

# 更新建造进度
func update_building(_delta: float) -> void:
	if not is_building or not current_building_target:
		return

	# 检查是否到达建造位置
	var distance_to_target = worker.global_position.distance_to(target_position)
	if distance_to_target > 5.0:  # 还没到达目标位置
		return

	# 已经到达建造位置，开始建造

	# 确保工人面向建筑
	var direction_to_building = (current_building_target.position - worker.global_position).normalized()
	if direction_to_building.x != 0:
		worker.animated_sprite_2d.flip_h = direction_to_building.x < 0

	# 检查是否可以执行新的建造动作
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_build_time < BUILD_INTERVAL:
		return

	# 如果工人没有在进行挖矿或砍树动画，开始新的建造动作
	if not worker.is_mining and not worker.is_chopping:
		# 执行建造动作（使用挖矿动画）
		worker.mining_manager.start_mine(direction_to_building, null)
		worker.is_mining = true  # 设置为挖矿状态，复用挖矿动画

		# 增加建筑血量
		var site_manager = get_site_manager()
		var completed = site_manager.contribute_to_building(current_building_target.id, BUILD_SPEED)

		# 更新最后建造时间
		last_build_time = current_time

		# 如果建造完成
		if completed:
			finish_building()

# 结束建造
func finish_building() -> void:
	if not is_building or not current_building_target:
		return

	print("工人完成建造任务: ", current_building_target.type)

	# 发出信号
	building_completed.emit(current_building_target.type, current_building_target.position)

	# 重置状态
	is_building = false
	current_building_target = null

# 获取建筑工地管理器
func get_site_manager() -> BuildingSiteManager:
	var site_manager = get_node_or_null("/root/BuildingSiteManager")
	if not site_manager:
		site_manager = BuildingSiteManager.new()
		site_manager.name = "BuildingSiteManager"
		get_tree().root.call_deferred("add_child", site_manager)
		print("创建了新的 BuildingSiteManager 实例")
	return site_manager

# 建造城堡
func build_castle(pos: Vector2) -> void:
	start_building(pos, "Castle")

# 建造房屋
func build_house(pos: Vector2) -> void:
	start_building(pos, "House")

# 建造箭塔
func build_tower(pos: Vector2) -> void:
	start_building(pos, "Tower")

# 取消建造
func cancel_building() -> void:
	if not is_building:
		return

	print("取消建造")

	# 通知建筑工地管理器取消此工人的贡献
	if current_building_target:
		var site_manager = get_site_manager()
		site_manager.unregister_worker(current_building_target.id, worker)

	# 重置状态
	is_building = false
	current_building_target = null

	# 恢复工人状态
	worker.is_mining = false
	worker.animation_manager.set_animation_state(Vector2.ZERO, worker.wood_manager.is_carrying)

# 修理建筑
func repair() -> void:
	print("工人开始修理建筑")
	# TODO: 实现修理逻辑
