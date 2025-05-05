# @file: goblin_base.gd
# @brief: 哥布林基类，所有哥布林类型的基础
# @author: ponywu

extends CharacterBody2D
class_name GoblinBase

# 方向枚举
enum Direction {
	UP,
	RIGHT,
	DOWN,
	LEFT
}

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
var random_timer: float = 0.0
var random_move_cooldown: float = 3.0
var attack_timer: float = 0.0

var move_direction: Vector2 = Vector2.ZERO  # 移动方向
var current_direction: Direction = Direction.DOWN  # 当前朝向

# 节点引用
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# 由子类覆盖的配置
var CONFIG = {
	"move_speed": 100.0,       # 移动速度
	"health": 50,              # 生命值
	"detection_radius": 150,   # 检测半径
	"attack_interval": 1.0,    # 攻击检测间隔
	"attack_distance": 60.0,   # 攻击距离 - 在此距离停止并攻击
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

	# 处理移动
	if current_state == BaseState.RUNNING and move_direction != Vector2.ZERO:
		velocity = move_direction * CONFIG.move_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		play_idle_animation()

# 处理攻击行为，子类需重写
func handle_attack() -> void:
	pass

# 寻找攻击目标
func find_target() -> void:
	if current_state == BaseState.DEAD:
		return

	# 检查当前目标是否有效
	if target != null:
		# 检查目标是否存在于场景树中（未被销毁）
		if !is_instance_valid(target) or !target.is_inside_tree():
			target = null
		# 检查目标是否超出检测范围
		elif global_position.distance_to(target.global_position) > CONFIG.detection_radius:
			target = null

	# 如果没有有效目标，寻找新目标
	if target == null:
		# 获取范围内的所有潜在目标
		var all_targets = []
		all_targets.append_array(get_group_nodes("soldiers"))
		all_targets.append_array(get_group_nodes("buildings"))

		# 如果有可攻击目标，选择最近的
		if all_targets.size() > 0:
			var closest_target = find_closest_node(all_targets)
			set_target(closest_target)

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

# 受到伤害
func take_damage(damage: int, knockback_force: Vector2 = Vector2.ZERO, idle_probability: float = 0) -> void:
	health -= damage

	if health <= 0:
		handle_death()
	else:
		# 受伤反馈
		modulate = Color(1, 0.5, 0.5)
		await get_tree().create_timer(0.2).timeout
		modulate = Color(1, 1, 1)

	if knockback_force != Vector2.ZERO:
		# 设置击退速度
		velocity = knockback_force
		# 应用物理移动
		move_and_slide()

		# 恢复正常动画
		if health > 0:
			if randf() < idle_probability:  # 打入僵直的概率
				change_state(BaseState.IDLE)

# 处理死亡
func handle_death() -> void:
	change_state(BaseState.DEAD)

# 播放待机动画
func play_idle_animation() -> void:
	animated_sprite.play("idle")


func _update_target_direction(t: Node2D) -> void:
	# 目标相对于当前角色的向量值
	move_direction = (t.global_position - global_position).normalized()
	_update_direction(move_direction)

func _update_direction(direction: Vector2) -> void:
	move_direction = direction
	if move_direction == Vector2.ZERO:
		return

	var angle = move_direction.angle()

	# 将弧度转换为角度
	var degrees = rad_to_deg(angle)

	if degrees >= -45 and degrees < 45:
		current_direction = Direction.RIGHT
		animated_sprite.flip_h = false
	elif degrees >= 45 and degrees < 135:
		current_direction = Direction.DOWN
	elif degrees >= -135 and degrees < -45:
		current_direction = Direction.UP
	else:
		current_direction = Direction.LEFT
		animated_sprite.flip_h = true
