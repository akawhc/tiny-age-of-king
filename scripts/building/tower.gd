# @file scripts/building/tower.gd
# @brief 塔类，继承自Building类，具有自动索敌和攻击功能
# @author ponywu
# @date 2025-04-21

extends Building

# 塔楼配置
const TOWER_CONFIG = {
	"attack_damage": 20,        # 攻击伤害（比弓箭手高）
	"attack_cooldown": 2.5,     # 攻击冷却时间(秒)
	"arrow_speed": 350.0,       # 箭矢速度
	"max_arrow_distance": 600.0 # 箭矢最大飞行距离
}

# 攻击相关
var target_enemy: Node2D = null
var attack_cooldown_timer: float = 0.0
var can_attack: bool = true
var enemies_in_range: Array = []
var attack_enabled: bool = true  # 是否启用自动攻击

# 箭矢场景路径
var arrow_scene_path: String = "res://scenes/projectiles/arrow.tscn"

# 箭矢生成位置偏移（从塔顶发射）
const ARROW_SPAWN_OFFSET = Vector2(0, -120)

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var detection_area: Area2D = $Area2D
@onready var attack_position: Marker2D = $AttackPosition

func _ready() -> void:
	building_type = "Tower"
	max_health = 500
	current_health = max_health

	# 确保塔被添加到正确的组
	add_to_group("towers")
	add_to_group("selectable_buildings")

	super._ready()

	# 设置检测区域
	_setup_detection_area()

	# 启动攻击循环
	set_process(true)

	# 确保鼠标输入处理启用
	input_pickable = true

# 设置检测区域
func _setup_detection_area() -> void:
	# 使用已有的Area2D节点
	if detection_area:
		# 确保碰撞掩码设置正确 - 要能够检测到敌人(哥布林)所在的层
		detection_area.collision_layer = 0  # 不需要被其他物体检测到
		detection_area.collision_mask = 1 | 2 | 4  # 检测第1层的物体(敌人)

		# 连接信号
		if !detection_area.is_connected("body_entered", _on_detection_area_body_entered):
			detection_area.body_entered.connect(_on_detection_area_body_entered)
		if !detection_area.is_connected("body_exited", _on_detection_area_body_exited):
			detection_area.body_exited.connect(_on_detection_area_body_exited)

		print("塔的检测区域设置完成")
	else:
		push_error("Tower: 找不到Area2D节点!")


# 重写摧毁纹理路径获取方法，如果有特定的塔摧毁纹理
func get_destroy_texture_path() -> String:
	return "res://sprites/Tiny Swords/Factions/Knights/Buildings/Tower/Tower_Destroyed.png"

func _process(delta: float) -> void:
	# 处理攻击冷却
	if !can_attack:
		attack_cooldown_timer += delta
		if attack_cooldown_timer >= TOWER_CONFIG.attack_cooldown:
			can_attack = true
			attack_cooldown_timer = 0.0

	# 如果启用自动攻击且有敌人目标且可以攻击，则开始攻击
	if attack_enabled and target_enemy and can_attack:
		start_attack()

func _on_detection_area_body_entered(body: Node2D) -> void:
	# 检测进入范围的敌人
	if body.is_in_group("goblin"):
		enemies_in_range.append(body)
		update_target()

func _on_detection_area_body_exited(body: Node2D) -> void:
	# 敌人离开检测范围
	if body.is_in_group("goblin"):
		if enemies_in_range.has(body):
			enemies_in_range.erase(body)
		if body == target_enemy:
			target_enemy = null
		update_target()

# 更新目标敌人为最近的哥布林
func update_target() -> void:
	var closest_enemy = null
	var closest_distance = INF

	for enemy in enemies_in_range:
		if is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy

	target_enemy = closest_enemy

# 开始攻击
func start_attack() -> void:
	if !can_attack:
		return

	can_attack = false

	# 立即射出箭矢，塔不需要播放动画
	shoot_arrow()

# 发射箭矢
func shoot_arrow() -> void:
	if !target_enemy or !is_instance_valid(target_enemy):
		# 如果目标不再有效，尝试获取新目标
		update_target()
		if !target_enemy:
			return

	# 获取攻击位置
	var spawn_position = attack_position.global_position if attack_position else (global_position + ARROW_SPAWN_OFFSET)

	# 计算射击方向：从射出点到目标点的方向
	var shoot_direction = (target_enemy.global_position - spawn_position).normalized()

	# 检查箭矢场景是否存在
	var arrow_scene_res = ResourceLoader.exists(arrow_scene_path)
	if !arrow_scene_res:
		push_error("箭矢场景路径不存在: " + arrow_scene_path)
		return

	# 加载箭矢场景
	var arrow_scene = load(arrow_scene_path)
	if arrow_scene:
		var arrow_instance = arrow_scene.instantiate()

		# 设置箭矢参数
		arrow_instance.global_position = spawn_position

		# 使用箭矢的initialize方法初始化
		arrow_instance.initialize(
			shoot_direction,
			TOWER_CONFIG.attack_damage,
			TOWER_CONFIG.arrow_speed,
			self,
			TOWER_CONFIG.max_arrow_distance
		)

		# 将箭矢添加到场景
		get_tree().get_root().add_child(arrow_instance)

		print("塔发射了一支箭，目标: ", target_enemy.name, "，方向: ", shoot_direction)
	else:
		push_error("无法加载箭矢场景: " + arrow_scene_path)

# 添加测试方法，可通过代码调用测试
func test_shoot(target_position: Vector2) -> void:
	# 确保箭矢场景存在
	if !ResourceLoader.exists(arrow_scene_path):
		push_error("测试射击失败: 箭矢场景不存在: " + arrow_scene_path)
		return

	# 获取射击位置
	var spawn_position = attack_position.global_position if attack_position else (global_position + ARROW_SPAWN_OFFSET)

	# 计算射击方向
	var shoot_direction = (target_position - spawn_position).normalized()

	# 加载箭矢场景
	var arrow_scene = load(arrow_scene_path)
	if arrow_scene:
		var arrow_instance = arrow_scene.instantiate()

		# 设置箭矢参数
		arrow_instance.global_position = spawn_position

		# 使用箭矢的initialize方法初始化
		arrow_instance.initialize(
			shoot_direction,
			TOWER_CONFIG.attack_damage,
			TOWER_CONFIG.arrow_speed,
			self,
			TOWER_CONFIG.max_arrow_distance
		)

		# 将箭矢添加到场景
		get_tree().get_root().add_child(arrow_instance)

		print("测试箭矢已发射，方向:", shoot_direction)
	else:
		push_error("测试射击失败: 无法加载箭矢场景")
