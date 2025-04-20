# @file: building_site_manager.gd
# @brief: 建筑工地管理器，管理所有正在建造的建筑
# @author: ponywu
# @date: 2025-04-13

class_name BuildingSiteManager
extends Node

# 建筑站点数据结构
class BuildingSite:
	var id: String
	var position: Vector2
	var type: String
	var max_health: float
	var current_health: float
	var workers: Array = []
	var completed: bool = false
	var foundation_sprite: Node2D = null  # 建筑地基精灵

	func _init(site_id: String, pos: Vector2, building_type: String):
		id = site_id
		position = pos
		type = building_type

		# 根据建筑类型设置最大生命值
		match type:
			"Castle":
				max_health = 10.0  # 城堡需要10点生命值
			"House":
				max_health = 5.0   # 房屋需要5点生命值
			"Tower":
				max_health = 7.0   # 箭塔需要7点生命值
			_:
				max_health = 5.0   # 默认值

		current_health = 0.0

# 所有活动的建筑工地，使用唯一ID作为键
var active_building_sites = {}

# 信号
signal building_site_created(site_id, type, position)
signal building_site_progress(site_id, progress)
signal building_site_completed(site_id, type, position)

# 资源路径
const BASE_RESOURCE_PATH = "res://sprites/Tiny Swords/Factions/Knights/Buildings/"

# 创建互斥锁，用于控制对建筑站点的并发访问
var _building_mutex = Mutex.new()

func _ready():
	# 确保添加到全局场景树中
	name = "BuildingSiteManager"

# 注册新的建筑工地，或返回现有工地
func register_building_site(pos: Vector2, type: String, worker) -> BuildingSite:
	# 检查是否已经存在相同位置的建筑工地
	var existing_site = find_site_at_position(pos)
	if existing_site:
		# 如果存在，添加工人到这个工地
		if not existing_site.workers.has(worker):
			existing_site.workers.append(worker)
		print("工人加入已存在的建筑工地: ", existing_site.id, "，类型: ", existing_site.type)
		return existing_site

	# 创建新的建筑工地
	var site_id = generate_site_id(pos, type)
	var site = BuildingSite.new(site_id, pos, type)
	site.workers.append(worker)

	# 添加到活动建筑工地列表
	active_building_sites[site_id] = site

	# 创建建筑地基精灵
	create_foundation_sprite(site)

	print("创建新建筑工地: ", site_id, "，类型: ", type, "，位置: ", pos)
	emit_signal("building_site_created", site_id, type, pos)

	return site

# 创建建筑地基精灵
func create_foundation_sprite(site: BuildingSite) -> void:
	# 创建一个容器节点
	var container = Node2D.new()
	container.position = site.position
	container.z_index = 5
	add_child(container)

	# 创建地基精灵
	var sprite = Sprite2D.new()
	sprite.centered = true
	container.add_child(sprite)

	# 根据建筑类型加载对应的建造中纹理
	var texture_path = get_construction_texture_path(site.type)
	var texture = load(texture_path)
	if texture:
		sprite.texture = texture
	else:
		push_error("无法加载建筑地基纹理: " + texture_path)
		return

	# 创建进度条
	var progress_bg = ColorRect.new()
	progress_bg.color = Color(0.1, 0.1, 0.1, 0.8)  # 深灰色背景
	progress_bg.size = Vector2(60, 8)  # 进度条大小
	progress_bg.position = Vector2(-30, -50)  # 位置调整
	container.add_child(progress_bg)

	var progress_bar = ColorRect.new()
	progress_bar.color = Color(0.2, 0.8, 0.2, 1.0)  # 绿色进度
	progress_bar.size = Vector2(0, 8)  # 初始宽度为0
	progress_bar.position = Vector2(-30, -50)  # 与背景相同位置
	progress_bar.name = "ProgressBar"
	container.add_child(progress_bar)

	# 设置初始透明度
	sprite.modulate.a = 0.7

	# 保存引用
	site.foundation_sprite = container

	print("创建建筑地基: ", site.type, " 在位置 ", site.position)

# 获取建筑建造中的纹理路径
func get_construction_texture_path(building_type: String) -> String:
	match building_type:
		"Castle":
			return BASE_RESOURCE_PATH + "Castle/Castle_Construction.png"
		"House":
			return BASE_RESOURCE_PATH + "House/House_Construction.png"
		"Tower":
			return BASE_RESOURCE_PATH + "Tower/Tower_Construction.png"
		_:
			return BASE_RESOURCE_PATH + "Castle/Castle_Construction.png"

# 工人对建筑进行贡献（增加建筑血量）
func contribute_to_building(site_id: String, amount: float) -> bool:
	# 获取互斥锁，确保同一时刻只有一个工人修改特定建筑的状态
	_building_mutex.lock()

	# 初始化结果变量
	var result = false
	var site_completed = false

	# 检查建筑工地是否存在
	if not active_building_sites.has(site_id):
		print("错误: 尝试贡献到不存在的建筑工地: ", site_id)
		_building_mutex.unlock()
		return false

	var site = active_building_sites[site_id]

	# 如果已经完成，不再接受贡献
	if site.completed:
		_building_mutex.unlock()
		return true

	# 增加建筑血量
	site.current_health += amount
	var progress = site.current_health / site.max_health

	# 更新地基精灵显示（可以添加进度效果）
	update_foundation_progress(site, progress)

	# 发送进度信号
	emit_signal("building_site_progress", site_id, progress)
	print("建筑工地 ", site_id, " 的进度: ", int(progress * 100), "%")

	# 检查是否完成
	if site.current_health >= site.max_health:
		site.completed = true
		site_completed = true
		result = true

	# 解锁互斥锁
	_building_mutex.unlock()

	# 如果建筑完成，在锁外调用完成函数
	if site_completed:
		# 使用call_deferred以确保在主线程安全地完成建筑
		call_deferred("complete_building_site", site_id)

	return result

# 更新地基进度显示
func update_foundation_progress(site: BuildingSite, progress: float) -> void:
	if not site.foundation_sprite:
		return

	# 更新进度条
	var progress_bar = site.foundation_sprite.get_node_or_null("ProgressBar")
	if progress_bar:
		progress_bar.size.x = 60 * progress

		# 进度超过50%时添加工人在建筑上的特效
		if progress > 0.5:
			# 增加闪烁效果
			var sprite = site.foundation_sprite.get_child(0)  # 假设第一个子节点是精灵
			if sprite is Sprite2D:
				var tween = create_tween()
				tween.tween_property(sprite, "modulate:a", 0.6 + (randf() * 0.3), 0.3)
				tween.tween_property(sprite, "modulate:a", 0.8, 0.3)

		# 根据进度更改进度条颜色
		if progress < 0.3:
			progress_bar.color = Color(0.9, 0.1, 0.1, 1.0)  # 红色
		elif progress < 0.7:
			progress_bar.color = Color(0.9, 0.7, 0.1, 1.0)  # 黄色
		else:
			progress_bar.color = Color(0.1, 0.9, 0.1, 1.0)  # 绿色

# 完成建筑工地，生成实际建筑
func complete_building_site(site_id: String) -> void:
	if not active_building_sites.has(site_id):
		return

	var site = active_building_sites[site_id]
	print("建筑工地 ", site_id, " 完成建造！")

	# 移除地基精灵
	if site.foundation_sprite:
		site.foundation_sprite.queue_free()

	# 发送完成信号
	emit_signal("building_site_completed", site_id, site.type, site.position)

	# 通知建筑管理器生成实际建筑
	var building_manager = BuildingManager.get_instance()
	if building_manager:
		building_manager.spawn_building(site.type, site.position)

	# 移除已完成的工地
	active_building_sites.erase(site_id)

# 取消工人的注册（当工人死亡或被分配到其他任务时）
func unregister_worker(site_id: String, worker) -> void:
	if not active_building_sites.has(site_id):
		return

	var site = active_building_sites[site_id]

	# 从工人列表中移除
	if site.workers.has(worker):
		site.workers.erase(worker)
		print("工人离开建筑工地: ", site_id)

	# 如果没有工人了，可以选择移除这个建筑工地或保留它
	if site.workers.is_empty() and not site.completed:
		print("建筑工地 ", site_id, " 没有工人，等待新工人...")
		# 可以选择加入延迟删除机制，如果长时间没有工人就删除工地

# 根据位置查找建筑工地
func find_site_at_position(pos: Vector2, tolerance: float = 10.0) -> BuildingSite:
	for site_id in active_building_sites:
		var site = active_building_sites[site_id]
		if site.position.distance_to(pos) <= tolerance:
			return site
	return null

# 生成唯一的建筑工地ID
func generate_site_id(pos: Vector2, type: String) -> String:
	var timestamp = Time.get_unix_time_from_system()
	return type + "_" + str(int(pos.x)) + "_" + str(int(pos.y)) + "_" + str(timestamp)
