# @file: goblin_base.gd
# @brief: 哥布林基类，所有哥布林类型的基础
# @author: ponywu

extends CharacterBody2D
class_name GoblinBase

# 基础状态
enum BaseState {
	IDLE,      # 待机
	RUNNING,   # 奔跑
	DEAD       # 死亡/销毁
}

# 基础变量
var current_state: int = BaseState.IDLE  # 使用int类型以兼容子类扩展的状态枚举
var health: int = 50
var target: Node2D = null
var move_direction: Vector2 = Vector2.ZERO
var random_timer: float = 0.0
var random_move_cooldown: float = 3.0
var attack_timer: float = 0.0

# 节点引用
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# 由子类覆盖的配置
var CONFIG = {
	"move_speed": 100.0,      # 移动速度
	"health": 50,             # 生命值
	"detection_radius": 150,  # 检测半径
	"attack_interval": 1.0,   # 攻击检测间隔
}

func _ready() -> void:
	# 添加到敌人组
	add_to_group("goblin")

	# 初始化
	initialize()

	# 播放初始动画
	play_idle_animation()

	# 生成随机移动间隔
	randomize()
	random_move_cooldown = randf_range(2.0, 5.0)

# 初始化方法，子类可重写
func initialize() -> void:
	health = CONFIG.health

func _process(delta: float) -> void:
	# 处理攻击检测计时器
	attack_timer += delta
	if attack_timer >= CONFIG.attack_interval:
		attack_timer = 0
		find_target()

	# 处理随机移动计时器
	if current_state == BaseState.IDLE:
		random_timer += delta
		if random_timer >= random_move_cooldown:
			random_timer = 0
			random_move_cooldown = randf_range(2.0, 5.0)
			_random_action()

	# 进行状态更新
	process_state(delta)

# 状态处理，子类需重写
func process_state(_delta: float) -> void:
	pass

func _physics_process(_delta: float) -> void:
	# 如果是死亡状态，不移动
	if current_state == BaseState.DEAD:
		velocity = Vector2.ZERO
		return

	# 如果有目标，向目标移动
	if target and current_state == BaseState.RUNNING:
		move_direction = (target.global_position - global_position).normalized()
		velocity = move_direction * CONFIG.move_speed
	else:
		# 否则按当前移动方向移动
		velocity = move_direction * CONFIG.move_speed

		# 如果速度很小，视为静止
		if velocity.length() < 10:
			velocity = Vector2.ZERO
			if current_state == BaseState.RUNNING:
				change_state(BaseState.IDLE)

	# 应用移动
	move_and_slide()

# 寻找攻击目标
func find_target() -> void:
	if current_state == BaseState.DEAD:
		return

	# 获取范围内的攻击目标
	var characters = get_group_nodes("soldiers")
	var buildings = get_group_nodes("buildings")

	# 优先攻击角色，其次是建筑
	if characters.size() > 0:
		var closest_character = find_closest_node(characters)
		set_target(closest_character)
	elif buildings.size() > 0:
		var closest_building = find_closest_node(buildings)
		set_target(closest_building)
	else:
		target = null

func get_group_nodes(group_name: String) -> Array:
	var group_nodes = get_tree().get_nodes_in_group(group_name)
	var targets = []
	for node in group_nodes:
		var distance = global_position.distance_to(node.global_position)
		if distance <= CONFIG.detection_radius:
			targets.append(node)
	return targets

# 找到最近的节点
func find_closest_node(nodes: Array) -> Node2D:
	var closest_node = null
	var closest_distance = INF

	for node in nodes:
		var distance = global_position.distance_to(node.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_node = node

	return closest_node

# 随机行为，子类可重写
func _random_action() -> void:
	# 如果已经有目标，不执行随机行为
	if target != null:
		return

	var action = randi() % 5

	match action:
		0, 1:
			# 随机移动
			move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			change_state(BaseState.RUNNING)
			# 移动一段时间后停下
			await get_tree().create_timer(randf_range(1.0, 3.0)).timeout
			move_direction = Vector2.ZERO
		_:
			# 待机
			change_state(BaseState.IDLE)

# 改变状态
func change_state(new_state: int) -> void:
	if current_state == new_state:
		return

	# 已经死亡则不能改变状态
	if current_state == BaseState.DEAD:
		return

	var old_state = current_state
	current_state = new_state

	# 处理状态进入动作
	on_state_enter(new_state, old_state)

# 状态进入处理，子类需重写
func on_state_enter(_new_state: int, _old_state: int) -> void:
	pass

# 设置目标
func set_target(new_target: Node2D) -> void:
	target = new_target
	if target:
		change_state(BaseState.RUNNING)

# 受到伤害
func take_damage(damage: int) -> void:
	health -= damage

	if health <= 0:
		handle_death()
	else:
		# 受伤反馈
		modulate = Color(1, 0.5, 0.5)
		await get_tree().create_timer(0.2).timeout
		modulate = Color(1, 1, 1)

# 处理死亡
func handle_death() -> void:
	change_state(BaseState.DEAD)

# 播放待机动画
func play_idle_animation() -> void:
	animated_sprite.play("idle")