# @file: torch.gd
# @brief: 火把哥布林脚本
# @author: ponywu

extends CharacterBody2D

# 配置参数
const CONFIG = {
	"move_speed": 110.0,      # 移动速度
	"health": 60,             # 生命值
	"detection_radius": 200,  # 检测半径
	"attack_range": 45,       # 攻击范围
	"attack_damage": 15,      # 攻击伤害
	"attack_cooldown": 1.5,   # 攻击冷却时间(秒)
}

# 方向枚举
enum Direction {
	UP,
	RIGHT,
	DOWN,
	LEFT
}

# 状态
enum State {
	IDLE,       # 待机
	RUNNING,    # 奔跑
	ATTACKING,  # 攻击
	DEAD        # 死亡
}

# 变量
var current_state: State = State.IDLE
var current_direction: Direction = Direction.DOWN
var health: int = CONFIG.health
var target: Node2D = null
var move_direction: Vector2 = Vector2.ZERO
var attack_cooldown: float = 0.0
var can_attack: bool = true
var random_timer: float = 0.0
var random_move_cooldown: float = 3.0

# 节点引用
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# 添加到敌人组
	add_to_group("enemies")

	# 初始化
	animated_sprite.play("idle")

	# 生成随机移动间隔
	randomize()
	random_move_cooldown = randf_range(2.0, 5.0)

	# 监听动画完成事件
	animated_sprite.animation_finished.connect(_on_animation_finished)

func _process(delta: float) -> void:
	# 攻击冷却
	if !can_attack:
		attack_cooldown += delta
		if attack_cooldown >= CONFIG.attack_cooldown:
			attack_cooldown = 0.0
			can_attack = true

	# 处理随机移动计时器
	if current_state == State.IDLE:
		random_timer += delta
		if random_timer >= random_move_cooldown:
			random_timer = 0
			random_move_cooldown = randf_range(2.0, 5.0)
			_random_action()

	# 状态机更新
	match current_state:
		State.IDLE:
			# 如果有目标并且在检测范围内，追击目标
			if target and global_position.distance_to(target.global_position) < CONFIG.detection_radius:
				change_state(State.RUNNING)

		State.RUNNING:
			if target:
				var distance = global_position.distance_to(target.global_position)
				# 如果在攻击范围内且可以攻击，进行攻击
				if distance < CONFIG.attack_range and can_attack:
					change_state(State.ATTACKING)
				# 否则继续追击
				else:
					move_direction = (target.global_position - global_position).normalized()
					_update_direction(move_direction)
			else:
				# 没有目标时，随机移动或回到待机
				if move_direction.length() < 0.1:
					change_state(State.IDLE)

		State.ATTACKING:
			# 攻击动画中，不移动
			pass

		State.DEAD:
			# 死亡状态
			pass

func _physics_process(delta: float) -> void:
	# 如果在攻击或死亡状态，不移动
	if current_state == State.ATTACKING or current_state == State.DEAD:
		velocity = Vector2.ZERO
		return

	# 应用移动
	velocity = move_direction * CONFIG.move_speed
	move_and_slide()

# 更新朝向
func _update_direction(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		# 水平方向
		if direction.x > 0:
			current_direction = Direction.RIGHT
		else:
			current_direction = Direction.LEFT
	else:
		# 垂直方向
		if direction.y > 0:
			current_direction = Direction.DOWN
		else:
			current_direction = Direction.UP

# 随机行为
func _random_action() -> void:
	var action = randi() % 5

	match action:
		0, 1:
			# 随机移动
			move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			_update_direction(move_direction)
			change_state(State.RUNNING)
			# 移动一段时间后停下
			await get_tree().create_timer(randf_range(1.0, 2.0)).timeout
			move_direction = Vector2.ZERO
		_:
			# 待机
			change_state(State.IDLE)

# 改变状态
func change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	# 退出当前状态
	match current_state:
		State.DEAD:
			# 已经死亡则不能改变状态
			return

	# 进入新状态
	current_state = new_state

	match new_state:
		State.IDLE:
			animated_sprite.play("idle")
		State.RUNNING:
			animated_sprite.play("run")
		State.ATTACKING:
			_play_attack_animation()
			_do_attack()
		State.DEAD:
			# 播放死亡动画或特效
			queue_free()

# 播放对应方向的攻击动画
func _play_attack_animation() -> void:
	match current_direction:
		Direction.UP:
			animated_sprite.play("attack_back")
		Direction.RIGHT:
			animated_sprite.flip_h = false
			animated_sprite.play("attack_right")
		Direction.DOWN:
			animated_sprite.play("attack_down")
		Direction.LEFT:
			animated_sprite.flip_h = true
			animated_sprite.play("attack_right")

# 进行攻击
func _do_attack() -> void:
	if !can_attack or !target:
		return

	can_attack = false

	# 实际攻击逻辑将在动画的特定帧触发
	print("火把哥布林准备攻击!")

# 在攻击动画特定帧进行实际伤害判定
func _apply_attack_damage() -> void:
	if !target or global_position.distance_to(target.global_position) > CONFIG.attack_range:
		return

	# 造成伤害
	if target.has_method("take_damage"):
		target.take_damage(CONFIG.attack_damage)
		print("火把哥布林攻击命中，造成", CONFIG.attack_damage, "点伤害!")

# 动画完成回调
func _on_animation_finished() -> void:
	if animated_sprite.animation.begins_with("attack_"):
		change_state(State.IDLE)

# 受到伤害
func take_damage(damage: int) -> void:
	health -= damage

	if health <= 0:
		change_state(State.DEAD)
	else:
		# 受伤反馈
		modulate = Color(1, 0.5, 0.5)
		await get_tree().create_timer(0.2).timeout
		modulate = Color(1, 1, 1)

# 设置目标
func set_target(new_target: Node2D) -> void:
	target = new_target
	if target:
		change_state(State.RUNNING)