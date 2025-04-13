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
const BUILD_SPEED = 1  # 每次敲击增加的建造进度

# 建造目标信息
var target_position = Vector2.ZERO  # 工人的目标位置

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

# 建造城堡
func build_castle(pos: Vector2) -> void:
	start_building(pos, "Castle")

# 建造房屋
func build_house(pos: Vector2) -> void:
	start_building(pos, "House")

# 建造箭塔
func build_tower(pos: Vector2) -> void:
	start_building(pos, "Tower")

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
	worker.is_building = true  # 设置工人的建造状态

	# 获取或创建建筑目标
	var site_manager = get_site_manager()
	current_building_target = site_manager.register_building_site(pos, building_type, worker)

	print("工人开始建造 ", building_type, "，目标位置: ", target_position)

# 更新建造进度
func update_building(_delta: float) -> void:
	if not is_building or not current_building_target:
		if is_building:
			print("工人无法建造: 当前建造目标丢失")
		return

	# 检查是否到达建造位置
	var distance_to_target = worker.global_position.distance_to(target_position)
	if distance_to_target > 5.0:  # 还没到达目标位置
		return

	# 确保工人面向建筑
	var direction_to_building = (current_building_target.position - worker.global_position).normalized()
	if direction_to_building.x != 0:
		worker.animated_sprite_2d.flip_h = direction_to_building.x < 0

	# 如果工人没有在执行其他动画，开始新的建造动作
	if not worker.is_chopping and not worker.is_mining:
		# 开始播放建造动画
		start_build_animation(direction_to_building)

# 开始建造动画
func start_build_animation(facing_direction: Vector2) -> void:
	# 根据朝向设置动画翻转
	worker.animated_sprite_2d.flip_h = facing_direction.x < 0

	# 播放hammer动画
	worker.animated_sprite_2d.play("hammer")

# 建造动画帧变化的处理（在worker.gd中会被调用）
func on_build_animation_frame_changed(frame: int) -> void:
	# 检查是否到了造成建造效果的关键帧
	if frame == 5:
		# 增加建筑血量
		var site_manager = get_site_manager()
		var completed = site_manager.contribute_to_building(current_building_target.id, BUILD_SPEED)

		# 如果建造完成
		if completed:
			print("建筑完成，结束建造流程")
			finish_building()

		# 播放建造特效
		play_build_effect()

# 建造动画完成的处理
func on_build_animation_finished() -> void:
	print("建造动作完成，准备下一次建造")

# 播放建造特效
func play_build_effect() -> void:
	# 这里可以添加建造特效，如粒子效果等
	pass

# 结束建造
func finish_building() -> void:
	if not is_building or not current_building_target:
		return

	print("工人完成建造任务: ", current_building_target.type)

	# 发出信号
	building_completed.emit(current_building_target.type, current_building_target.position)

	# 重置状态
	is_building = false
	worker.is_building = false
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
	worker.is_building = false
	current_building_target = null

	# 恢复工人状态
	worker.animation_manager.set_animation_state(Vector2.ZERO, worker.wood_manager.is_carrying)

# 修理建筑
func repair() -> void:
	print("工人开始修理建筑")
	# TODO: 实现修理逻辑
