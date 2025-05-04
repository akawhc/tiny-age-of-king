# @file: build_manager.gd
# @brief: 工人建造管理器组件
# @author: ponywu
# @date: 2025-04-13

extends Node

# 建造状态 - 每个工人只能同时建造一个建筑
var is_building = false
var current_building_target = null  # 当前正在建造的建筑对象

# 建造参数
const TARGET_BUILD_REACH_DISTANCE = 10.0 # 工人需要到达目标位置的距离阈值
const BUILD_SPEED = 1  # 每次敲击增加的建造进度
const BUILD_OUTER_MARGIN = 10.0 # 工人与建筑边缘的距离

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

	# 获取或创建建筑目标
	var site_manager = get_site_manager()
	current_building_target = site_manager.register_building_site(pos, building_type, worker)

	# 检查建筑工地是否成功创建
	if current_building_target == null:
		print("错误：无法创建建筑工地")
		is_building = false
		# 注意：这里可能需要通知 site_manager 注销这个失败的工地，取决于其实现
		return

	# --- 新逻辑：计算建筑外部的目标位置 ---
	# 获取建筑尺寸 (需要根据实际情况实现 get_building_size)
	var building_size = get_building_size(building_type)
	if building_size == Vector2.ZERO:
		print("错误: 无法获取建筑尺寸 ", building_type)
		# 清理：如果工地已注册，需要注销
		site_manager.unregister_building_site(current_building_target.id) # 假设有此方法
		current_building_target = null
		is_building = false
		return

	# 计算建筑的实际占地矩形
	var building_rect = Rect2(pos - building_size / 2.0, building_size)
	# 计算一个包含工人站立空间的外部目标矩形
	var target_rect = building_rect.grow(BUILD_OUTER_MARGIN)

	# 寻找目标矩形边框上离工人最近的点
	target_position = find_closest_point_on_rect_perimeter(target_rect, worker.global_position)
	# --- 结束新逻辑 ---

	# 移动到建造位置
	worker.move_to(target_position)

	is_building = true

	print("工人开始建造 ", building_type, "，目标位置: ", target_position)

	# 延迟设置工人的建造状态，避免过早阻止工人移动
	call_deferred("_defer_set_worker_building_state", true)

# 更新建造进度
func update_building(_delta: float) -> void:
	if not is_building or not current_building_target:
		if is_building:
			print("工人无法建造: 当前建造目标丢失")
			is_building = false
			worker.is_building = false
		return

	# 检查是否到达建造位置
	var distance_to_target = worker.global_position.distance_to(target_position)

	# 距离检查 - 如果距离大于阈值，工人还没到达目标位置
	if distance_to_target > TARGET_BUILD_REACH_DISTANCE:
		# 如果工人离目标位置太远，可能是路径找不到，尝试重新寻路 (减少重新寻路的检查距离)
		if distance_to_target > 50.0 and randf() < 0.01:  # 1%概率尝试重新寻路
			print("工人离建造位置较远，尝试重新寻路")
			worker.move_to(target_position)
		return

	# 确保工人面向建筑 (目标中心点)
	var direction_to_building_center = (current_building_target.position - worker.global_position).normalized()
	if direction_to_building_center.x != 0:
		worker.animated_sprite_2d.flip_h = direction_to_building_center.x < 0

	# 如果工人没有在执行其他动画且已到达目标位置，开始新的建造动作
	if not worker.is_chopping and not worker.is_mining:
		start_build_animation(direction_to_building_center) # 使用朝向建筑中心的方向

# 开始建造动画
func start_build_animation(facing_direction: Vector2) -> void:
	# 根据朝向设置动画翻转
	worker.animated_sprite_2d.flip_h = facing_direction.x < 0

	# 播放hammer动画
	worker.animated_sprite_2d.play("hammer")

# 动画帧变化的处理（在worker.gd中会被调用）
func on_build_animation_frame_changed(frame: int) -> void:
	# 首先检查是否有有效的建造目标
	if not is_building or not current_building_target:
		return

	# 检查工人是否已经到达建造位置
	var distance_to_target = worker.global_position.distance_to(target_position)
	if distance_to_target > TARGET_BUILD_REACH_DISTANCE: # 使用常量
		# 工人还没到达建造位置，不应该增加建造进度
		return

	# 检查是否到了造成建造效果的关键帧
	if frame == 5:
		# 获取建筑工地管理器
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

# 停止建造（可能是因为建筑完成或其他原因）
func stop_building() -> void:
	if not is_building:
		return

	print("工人停止建造")

	# 重置状态
	is_building = false
	worker.is_building = false
	current_building_target = null

	# 恢复工人状态
	worker.animation_manager.set_animation_state(Vector2.ZERO, worker.wood_manager.is_carrying)

# 延迟设置工人的建造状态
func _defer_set_worker_building_state(state: bool) -> void:
	worker.is_building = state
	print("设置工人建造状态为: ", state)

# --- Helper Functions ---

# 辅助函数：根据建筑类型获取尺寸 (需要根据实际项目结构实现)
# 注意：这里的尺寸应该是建筑碰撞体或占地面积的尺寸
func get_building_size(building_type: String) -> Vector2:
	# 示例：需要从配置文件、场景或其他地方加载实际尺寸
	match building_type:
		"Castle":
			return Vector2(250, 150) # 假设城堡尺寸 (示例值)
		"House":
			return Vector2(100, 60)   # 假设房屋尺寸 (示例值)
		"Tower":
			return Vector2(100, 50)   # 假设箭塔尺寸 (示例值)
		_:
			printerr("未知的建筑类型，无法获取尺寸: ", building_type)
			return Vector2.ZERO

# 辅助函数：寻找矩形边框上离给定点最近的点
func find_closest_point_on_rect_perimeter(rect: Rect2, point: Vector2) -> Vector2:
	# 将点限制在矩形区域内
	var closest_point = point.clamp(rect.position, rect.position + rect.size)

	# 如果点恰好在矩形内部（意味着原始点也在内部），需要将其投射到最近的边框上
	var tolerance = 0.001
	if rect.has_point(point) and \
	   point.x > rect.position.x + tolerance and point.x < rect.end.x - tolerance and \
	   point.y > rect.position.y + tolerance and point.y < rect.end.y - tolerance:

		var dist_left = point.x - rect.position.x
		var dist_right = (rect.position.x + rect.size.x) - point.x
		var dist_top = point.y - rect.position.y
		var dist_bottom = (rect.position.y + rect.size.y) - point.y

		var min_dist = min(min(dist_left, dist_right), min(dist_top, dist_bottom))

		if abs(min_dist - dist_left) < tolerance:
			closest_point.x = rect.position.x
		elif abs(min_dist - dist_right) < tolerance:
			closest_point.x = rect.position.x + rect.size.x
		elif abs(min_dist - dist_top) < tolerance:
			closest_point.y = rect.position.y
		else: # abs(min_dist - dist_bottom) < tolerance:
			closest_point.y = rect.position.y + rect.size.y

	return closest_point
