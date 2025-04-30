# @file: torch.gd
# @brief: 火把哥布林脚本
# @author: ponywu

extends GoblinBase

# 方向枚举
enum Direction {
	UP,
	RIGHT,
	DOWN,
	LEFT
}

# 扩展状态
enum TorchState {
	IDLE = BaseState.IDLE,     # 继承基类状态
	RUNNING = BaseState.RUNNING,
	DEAD = BaseState.DEAD,
	ATTACKING = 10             # 自定义状态
}

# 火把哥布林特有变量
var current_direction: Direction = Direction.DOWN
var attack_cooldown: float = 0.0
var can_attack: bool = true

func _ready() -> void:
	# 配置参数
	CONFIG = {
		"move_speed": 110.0,      # 移动速度
		"health": 60,             # 生命值
		"detection_radius": 200,  # 检测半径
		"attack_range": 45,       # 攻击范围
		"attack_damage": 15,      # 攻击伤害
		"attack_cooldown": 1.5,   # 攻击冷却时间(秒)
		"attack_interval": 1.0,   # 攻击检测间隔
	}

	# 调用父类的_ready函数
	super._ready()

	# 监听动画完成事件
	animated_sprite.animation_finished.connect(_on_animation_finished)

# 重写初始化方法
func initialize() -> void:
	super.initialize()
	# 初始化特定变量
	can_attack = true
	attack_cooldown = 0.0
	current_direction = Direction.DOWN

# 重写播放待机动画
func play_idle_animation() -> void:
	animated_sprite.play("idle")

# 重写状态处理
func process_state(delta: float) -> void:
	# 攻击冷却
	if !can_attack:
		attack_cooldown += delta
		if attack_cooldown >= CONFIG.attack_cooldown:
			attack_cooldown = 0.0
			can_attack = true

	match current_state:
		TorchState.IDLE:
			# 如果有目标并且在检测范围内，追击目标
			if target and global_position.distance_to(target.global_position) < CONFIG.detection_radius:
				change_state(TorchState.RUNNING)

		TorchState.RUNNING:
			if target:
				var distance = global_position.distance_to(target.global_position)
				# 如果在攻击范围内且可以攻击，进行攻击
				if distance < CONFIG.attack_range and can_attack:
					change_state(TorchState.ATTACKING)
				# 否则继续追击
				else:
					move_direction = (target.global_position - global_position).normalized()
					_update_direction(move_direction)
			else:
				# 没有目标时，随机移动或回到待机
				if move_direction.length() < 0.1:
					change_state(TorchState.IDLE)

		TorchState.ATTACKING:
			# 攻击动画中，不移动
			pass

		TorchState.DEAD:
			# 死亡状态
			pass

# 重写物理处理
func _physics_process(_delta: float) -> void:
	# 如果在攻击或死亡状态，不移动
	if current_state == TorchState.ATTACKING or current_state == TorchState.DEAD:
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

# 重写随机行为
func _random_action() -> void:
	# 如果已经有目标，不执行随机行为
	if target != null:
		return

	var action = randi() % 5

	match action:
		0, 1:
			# 随机移动
			move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			_update_direction(move_direction)
			change_state(TorchState.RUNNING)
			# 移动一段时间后停下
			await get_tree().create_timer(randf_range(1.0, 2.0)).timeout
			move_direction = Vector2.ZERO
		_:
			# 待机
			change_state(TorchState.IDLE)

# 重写状态进入处理
func on_state_enter(new_state: int, _old_state: int) -> void:
	match new_state:
		TorchState.IDLE:
			animated_sprite.play("idle")
		TorchState.RUNNING:
			animated_sprite.play("run")
		TorchState.ATTACKING:
			_play_attack_animation()
			_do_attack()
		TorchState.DEAD:
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
		change_state(TorchState.IDLE)
