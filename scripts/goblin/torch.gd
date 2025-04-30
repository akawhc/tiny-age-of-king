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
	CONFIG = {
		"move_speed": 110.0,      # 移动速度
		"health": 6000,             # 生命值
		"detection_radius": 200,  # 检测半径
		"attack_range": 45,       # 攻击范围
		"attack_damage": 15,      # 攻击伤害
		"attack_cooldown": 1.5,   # 攻击冷却时间(秒)
		"attack_distance": 50.0,  # 攻击距离 - 应该与attack_range接近
		"approach_distance": 120.0, # 接近距离
		"min_distance": 45.0,     # 最小保持距离
		"attack_interval": 1.0,   # 攻击检测间隔
	}

	super._ready()

	# 监听动画完成事件
	animated_sprite.animation_finished.connect(_on_animation_finished)

func initialize() -> void:
	super.initialize()
	can_attack = true
	attack_cooldown = 0.0
	current_direction = Direction.DOWN

func play_idle_animation() -> void:
	animated_sprite.play("idle")

func process_state(delta: float) -> void:
	print("state process: ", current_state)
	# 攻击冷却
	if !can_attack:
		attack_cooldown += delta
		if attack_cooldown >= CONFIG.attack_cooldown:
			attack_cooldown = 0.0
			can_attack = true

	# 检查目标有效性
	if target != null and (!is_instance_valid(target) or !target.is_inside_tree()):
		target = null

	match current_state:
		TorchState.IDLE:
			if target:
				var distance = global_position.distance_to(target.global_position)
				# 如果在攻击范围内并且可以攻击，直接攻击
				if distance <= CONFIG.attack_range and can_attack:
					change_state(TorchState.ATTACKING)
				# 如果在检测范围内但超出攻击范围，开始追击
				elif distance < CONFIG.detection_radius and distance > CONFIG.attack_range:
					change_state(TorchState.RUNNING)

		TorchState.RUNNING:
			if target:
				var distance = global_position.distance_to(target.global_position)
				if distance <= CONFIG.attack_range and can_attack:
					change_state(TorchState.ATTACKING)
				elif distance > CONFIG.detection_radius:
					# 如果目标超出检测范围，停止追踪
					target = null
					move_direction = Vector2.ZERO
					change_state(TorchState.IDLE)
				else:
					move_direction = (target.global_position - global_position).normalized()
					_update_direction(move_direction)
			else:
				# 没有目标时，停止移动并回到待机
				move_direction = Vector2.ZERO
				change_state(TorchState.IDLE)

		TorchState.ATTACKING:
			# 攻击动画中，不做处理
			pass

		TorchState.DEAD:
			# 死亡状态
			pass

func handle_attack() -> void:
	if can_attack:
		change_state(TorchState.ATTACKING)

func _physics_process(delta: float) -> void:
	# 如果在攻击或死亡状态，不移动
	if current_state == TorchState.ATTACKING or current_state == TorchState.DEAD:
		velocity = Vector2.ZERO
		return

	# 如果有目标并且在RUNNING状态，处理移动逻辑
	if target and current_state == TorchState.RUNNING:
		var distance_to_target = global_position.distance_to(target.global_position)
		var direction_to_target = (target.global_position - global_position).normalized()

		# 如果在攻击距离内且可以攻击，停止并攻击
		if distance_to_target <= CONFIG.attack_distance and can_attack:
			velocity = Vector2.ZERO
			handle_attack()
		# 如果在接近距离内但大于攻击距离，正常移动接近目标
		else:
			move_direction = direction_to_target
			velocity = move_direction * CONFIG.move_speed
			# 更新朝向
			_update_direction(move_direction)

		# 应用移动
		move_and_slide()
	else:
		# 如果没有目标或在IDLE状态，使用基类的移动逻辑
		super._physics_process(delta)

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
			if current_state != TorchState.ATTACKING and current_state != TorchState.DEAD:
				move_direction = Vector2.ZERO
				change_state(TorchState.IDLE)
		_:
			# 待机
			change_state(TorchState.IDLE)

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

	# # 确保攻击动画不循环播放
	# if animated_sprite.sprite_frames.get_animation_loop(animated_sprite.animation):
	# 	animated_sprite.sprite_frames.set_animation_loop(animated_sprite.animation, false)
	# 	print("已将攻击动画设置为不循环播放: ", animated_sprite.animation)

func _do_attack() -> void:
	if !can_attack or !target:
		return

	can_attack = false

	# 实际攻击逻辑将在动画的特定帧触发
	print("火把哥布林准备攻击!")

func _apply_attack_damage() -> void:
	if !target or global_position.distance_to(target.global_position) > CONFIG.attack_range:
		return

	# 造成伤害
	if target.has_method("take_damage"):
		target.take_damage(CONFIG.attack_damage)
		print("火把哥布林攻击命中，造成", CONFIG.attack_damage, "点伤害!")

func _on_animation_finished() -> void:
	print("动画完成: ", animated_sprite.animation)
	if animated_sprite.animation.begins_with("attack_"):
		# 攻击结束后重新评估状态
		print("攻击动画结束，重新评估状态")
		change_state(TorchState.IDLE)

		# 攻击结束后立即检查目标位置
		if target and is_instance_valid(target) and target.is_inside_tree():
			var distance = global_position.distance_to(target.global_position)
			print("攻击后检查目标距离:", distance)

			# 如果目标在攻击范围内且可以攻击，再次攻击
			if distance <= CONFIG.attack_range and can_attack:
				print("目标仍在攻击范围内，继续攻击")
				change_state(TorchState.ATTACKING)
			# 如果目标在检测范围内但超出攻击范围，追击目标
			elif distance < CONFIG.detection_radius and distance > CONFIG.attack_range:
				print("目标已移动到攻击范围外，开始追击")
				change_state(TorchState.RUNNING)
