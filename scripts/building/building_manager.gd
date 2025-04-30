# file: building_manager.gd
# author: ponywu
# date: 2024-04-12
# description: 建筑管理器单例，负责处理所有建筑相关的操作

class_name BuildingManager

extends Node2D

# 单例实例
static var instance: BuildingManager = null

# 预加载的建筑预览纹理
var preview_textures = {
	"Castle": null,
	"House": null,
	"Tower": null
}

const resource_path = "res://sprites/Tiny Swords/Factions/Knights/Buildings/"

# 预览透明度和颜色
var valid_alpha = 0.7  # 可建造状态的透明度
var invalid_color = Color(1.0, 0.3, 0.3, 0.5)  # 不可建造状态为红色半透明

# 预览状态类
class PreviewState:
	var workers: Array  # 选中的工人
	var building_type: String  # 建筑类型
	var preview_sprite: Sprite2D  # 预览精灵

	func _init(workers_: Array, type: String, sprite: Sprite2D):
		workers = workers_
		building_type = type
		preview_sprite = sprite

# 当前活动的预览状态
var _current_preview: PreviewState = null

# 建筑操作信号
signal building_started(type: String)
signal building_completed(type: String, position: Vector2)
signal building_cancelled(type: String)

# 获取单例实例
static func get_instance() -> BuildingManager:
	if instance == null:
		# 创建新实例
		instance = BuildingManager.new()
		instance._load_preview_textures()

		# 确保添加到场景树中
		if Engine.is_editor_hint():
			return instance

		var scene_tree = Engine.get_main_loop()
		if scene_tree and scene_tree is SceneTree:
			scene_tree.root.call_deferred("add_child", instance)
			print("BuildingManager 单例已添加到场景树")
	return instance

# 加载所有建筑预览纹理
func _load_preview_textures() -> void:
	for building_type in preview_textures.keys():
		var texture_path = resource_path + building_type + "/" + building_type + "_Blue.png"
		preview_textures[building_type] = load(texture_path)
		print("预加载建筑预览纹理：", building_type)

func _input(event: InputEvent) -> void:
	if not _current_preview:
		return

	# 确保在场景树中并且有有效视口
	if not is_inside_tree() or get_viewport() == null:
		return

	if event is InputEventMouseMotion:
		# 更新预览位置
		var mouse_pos = get_global_mouse_position()
		_current_preview.preview_sprite.global_position = mouse_pos

		# 可建造时保持原色只改变透明度，不可建造时变为红色
		if can_build_at_position(mouse_pos):
			# 复制当前颜色但只修改透明度
			var color = _current_preview.preview_sprite.modulate
			color.a = valid_alpha
			_current_preview.preview_sprite.modulate = color
		else:
			# 不可建造时使用红色
			_current_preview.preview_sprite.modulate = invalid_color

	elif event.is_action_pressed("mouse_left"):  # 左键确认
		var build_pos = get_global_mouse_position()
		if can_build_at_position(build_pos):
			confirm_build(build_pos)

	elif event.is_action_pressed("mouse_right"):  # 右键取消
		cancel_build()

# 创建建筑预览
func start_preview(building_type: String, workers: Array) -> void:
	print("开始预览建筑：", building_type)

	# 如果已有预览，先取消
	if _current_preview:
		cancel_build()

	# 创建预览精灵
	var preview_sprite = Sprite2D.new()
	preview_sprite.centered = true
	preview_sprite.z_index = 100  # 确保预览显示在最上层

	# 设置预览纹理
	if preview_textures.has(building_type) and preview_textures[building_type] != null:
		preview_sprite.texture = preview_textures[building_type]
	else:
		push_error("未找到建筑预览纹理：" + building_type)
		return

	# 初始化透明度而不改变颜色
	preview_sprite.modulate.a = valid_alpha

	# 添加到场景中
	add_child(preview_sprite)

	# 设置初始位置
	# 只有当节点已经在场景树中并且有有效的 viewport 时，才尝试获取鼠标位置
	if is_inside_tree() and get_viewport() != null:
		preview_sprite.global_position = get_global_mouse_position()
	else:
		# 设置一个默认位置，之后在 _input 中会更新为鼠标位置
		preview_sprite.position = Vector2.ZERO
		print("警告：BuildingManager 不在场景树中或没有有效视口，无法获取鼠标位置")

	# 创建预览状态
	_current_preview = PreviewState.new(workers, building_type, preview_sprite)

	print("创建建筑预览：", building_type, "，工人数量：", workers.size())

# 停止预览
func stop_preview() -> void:
	if _current_preview:
		_current_preview.preview_sprite.queue_free()
		_current_preview = null

# 检查是否可以在指定位置建造
func can_build_at_position(_pos: Vector2) -> bool:
	# 这里添加建造位置的检查逻辑
	# 1. 检查是否与其他建筑重叠
	# 2. 检查是否在可建造区域内
	# 3. 检查是否有足够的资源

	# 返回 true 表示可建造
	return true

# 处理建造预览请求
func handle_preview_request(action: String, workers: Array) -> void:
	if workers.is_empty():
		print("没有工人被选中，无法开始建造")
		return

	# 开始预览
	match action:
		"build_castle":
			start_preview("Castle", workers)
		"build_house":
			start_preview("House", workers)
		"build_tower":
			start_preview("Tower", workers)
		"repair":
			start_repair(workers)

# 确认建造
func confirm_build(pos: Vector2) -> void:
	if not _current_preview:
		return

	var workers = _current_preview.workers
	var building_type = _current_preview.building_type

	print("确认在位置 ", pos, " 建造 ", building_type)

	match building_type:
		"Castle":
			start_castle_construction(workers, pos)
		"House":
			start_house_construction(workers, pos)
		"Tower":
			start_tower_construction(workers, pos)

	# 停止预览
	stop_preview()

# 取消建造
func cancel_build() -> void:
	if not _current_preview:
		return

	print("取消建造")
	building_cancelled.emit(_current_preview.building_type)
	stop_preview()

# 开始建造城堡
func start_castle_construction(workers: Array, pos: Vector2) -> void:
	if workers.is_empty():
		return

	print("开始在位置 ", pos, " 建造城堡")
	for worker in workers:
		worker.build_castle(pos)
	building_started.emit("Castle")

# 开始建造房屋
func start_house_construction(workers: Array, pos: Vector2) -> void:
	if workers.is_empty():
		return

	print("开始在位置 ", pos, " 建造房屋")
	for worker in workers:
		worker.build_house(pos)
	building_started.emit("House")

# 开始建造箭塔
func start_tower_construction(workers: Array, pos: Vector2) -> void:
	if workers.is_empty():
		return

	print("开始在位置 ", pos, " 建造箭塔")
	for worker in workers:
		worker.build_tower(pos)
	building_started.emit("Tower")

# 开始修理
func start_repair(workers: Array) -> void:
	if workers.is_empty():
		return

	for worker in workers:
		worker.repair()
	building_started.emit("Repair")

# 实例化建筑
func spawn_building(building_type: String, pos: Vector2) -> void:
	print("在位置 ", pos, " 实例化完整建筑: ", building_type)

	# 根据建筑类型加载对应的场景
	var scene_path = ""

	match building_type:
		"Castle":
			scene_path = "res://scenes/buildings/castle.tscn"
		"House":
			scene_path = "res://scenes/buildings/house.tscn"
		"Tower":
			scene_path = "res://scenes/buildings/tower.tscn"
		_:
			push_error("未知的建筑类型: " + building_type)
			return

	# 加载场景
	var building_scene = load(scene_path)
	if building_scene:
		# 实例化场景
		var building_instance = building_scene.instantiate()

		# 添加到场景树
		get_tree().current_scene.add_child(building_instance)
		building_instance.global_position = pos

		# 设置建筑名称
		building_instance.name = building_type + "_" + str(int(pos.x)) + "_" + str(int(pos.y))

		# 连接建筑被摧毁的信号
		building_instance.building_destroyed.connect(_on_building_destroyed)

		# 发出建筑完成信号
		building_completed.emit(building_type, pos)
		print("建筑 ", building_type, " 已创建完成")
	else:
		push_error("无法加载建筑场景: " + scene_path)

# 处理建筑被摧毁的回调
func _on_building_destroyed(building_type: String, pos: Vector2) -> void:
	print("建筑被摧毁: ", building_type, " 在位置 ", pos)
	# 在这里可以添加额外的逻辑，例如更新游戏状态、触发游戏事件等
