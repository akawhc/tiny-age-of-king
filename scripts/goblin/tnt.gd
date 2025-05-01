# @file: tnt.gd
# @brief: TNT哥布林脚本
# @author: ponywu

extends GoblinBase

# 扩展状态
enum TntState {
	IDLE = BaseState.IDLE,     # 继承基类状态
	RUNNING = BaseState.RUNNING,
	DEAD = BaseState.DEAD,
	THROWING = 10              # 自定义状态
}

# TNT特有变量
var throw_cooldown: float = 0.0
var can_throw: bool = true
var throw_cooldown_time: float = 3.0
var desired_direction = Vector2.ZERO  # 期望的移动方向
var turn_speed = 3.0                 # 转向速度

# TNT炸弹场景
@onready var bomb_scene = preload("res://scenes/projectiles/bomb.tscn")

# 投掷相关参数
const THROW_OFFSET_Y = -10  # 投掷高度偏移
const THROW_OFFSET_X = 20   # 投掷水平偏移

func _on_animation_frame_changed():
	if animated_sprite.animation == "throw":
		if animated_sprite.frame == animated_sprite.sprite_frames.get_frame_count("throw") - 2:
			spawn_and_throw_tnt()

func _ready() -> void:
	# 配置参数
	CONFIG = {
		"move_speed": 90.0,       # 移动速度
		"health": 40,             # 生命值
		"detection_radius": 200,  # 检测半径
		"throw_range": 150,       # 投掷范围
		"throw_damage": 40,       # 投掷伤害
		"explosion_radius": 100,   # 爆炸伤害半径
		"attack_interval": 1.0,   # 攻击检测间隔
		"min_throw_range": 80,    # 最小投掷距离
		"movement_x_random_range": 10.0,  # 移动随机范围
		"movement_y_random_range": 10.0,  # 移动随机范围
	}

	# 调用父类的_ready函数
	super._ready()

	# 监听动画完成事件
	animated_sprite.animation_finished.connect(_on_animation_finished)
	# 监听动画帧变化事件
	animated_sprite.frame_changed.connect(_on_animation_frame_changed)

func initialize() -> void:
	super.initialize()
	can_throw = true
	throw_cooldown = 0.0

func play_idle_animation() -> void:
	if current_direction == Direction.RIGHT:
		animated_sprite.flip_h = false
	elif current_direction == Direction.LEFT:
		animated_sprite.flip_h = true
	animated_sprite.play("idle")

func handle_attack() -> void:
	if can_throw:
		change_state(TntState.THROWING)

func _update_movement(delta: float, new_direction: Vector2) -> void:
	# 更新期望方向
	desired_direction = new_direction

	# 使用 lerp 进行平滑插值
	if desired_direction != Vector2.ZERO:
		move_direction = move_direction.lerp(desired_direction, delta * turn_speed)
		# 如果差距很小，直接设置为目标方向
		if move_direction.distance_to(desired_direction) < 0.1:
			move_direction = desired_direction

func process_state(delta: float) -> void:
	# 投掷冷却
	if !can_throw:
		throw_cooldown += delta
		if throw_cooldown >= throw_cooldown_time:
			throw_cooldown = 0.0
			can_throw = true

	# 检查目标有效性
	if target == null or (!is_instance_valid(target) or !target.is_inside_tree()):
		target = null
	else:
		_update_target_direction(target)

	match current_state:
		TntState.IDLE:
			if target:
				var distance = global_position.distance_to(target.global_position)
				if distance <= CONFIG.detection_radius:
					# 如果在投掷范围内并且可以投掷，直接投掷
					if distance <= CONFIG.throw_range and distance >= CONFIG.min_throw_range:
						if can_throw:
							change_state(TntState.THROWING)
					# 如果在检测范围内但不在理想投掷范围，开始移动调整位置
					else:
						change_state(TntState.RUNNING)

		TntState.RUNNING:
			if target:
				var distance = global_position.distance_to(target.global_position)
				# 超过视野范围，停止追踪
				if distance > CONFIG.detection_radius:
					target = null
					_update_movement(delta, Vector2.ZERO)
					change_state(TntState.IDLE)
				# 如果超出投掷范围，则继续追击，尝试进入投掷范围
				elif distance > CONFIG.throw_range:
					var new_direction = (target.global_position - global_position).normalized()
					_update_movement(delta, new_direction)
				# 如果距离太近，尝试拉开距离
				elif distance < CONFIG.min_throw_range:
					var new_direction = (global_position - target.global_position).normalized() * 0.6
					new_direction += Vector2(
						randf_range(-CONFIG.movement_x_random_range, CONFIG.movement_x_random_range),
						randf_range(-CONFIG.movement_y_random_range, CONFIG.movement_y_random_range)
					)
					_update_movement(delta, new_direction)
				# 如果在理想投掷范围内且可以投掷，进行投掷
				elif can_throw:
					change_state(TntState.THROWING)
				else:
					change_state(TntState.IDLE)
			else:
				# 没有目标时，停止移动并回到待机
				_update_movement(delta, Vector2.ZERO)
				change_state(TntState.IDLE)

		TntState.THROWING:
			if !target:
				change_state(TntState.IDLE)

		TntState.DEAD:
			# 死亡状态
			pass

func _physics_process(delta: float) -> void:
	# 如果在投掷或死亡状态，不移动
	if current_state == TntState.THROWING or current_state == TntState.DEAD:
		velocity = Vector2.ZERO
		return

	# 如果有目标并且在RUNNING状态，处理移动逻辑
	if target and current_state == TntState.RUNNING:
		var distance_to_target = global_position.distance_to(target.global_position)

		# 根据距离决定移动方向
		if distance_to_target < CONFIG.min_throw_range:
			move_direction = (global_position - target.global_position).normalized()
		elif distance_to_target > CONFIG.throw_range:
			move_direction = (target.global_position - global_position).normalized()

		velocity = move_direction * CONFIG.move_speed
		move_and_slide()
	else:
		# 如果没有目标或在其他状态，使用基类的移动逻辑
		super._physics_process(delta)


func throw_tnt() -> void:
	if !can_throw or !target:
		return

	can_throw = false
	spawn_and_throw_tnt()

func spawn_and_throw_tnt() -> void:
	if !target:
		return

	# 实例化炸弹
	var bomb = bomb_scene.instantiate()
	get_tree().get_root().add_child(bomb)

	# 计算投掷方向
	var throw_direction = (target.global_position - global_position).normalized()

	# 计算生成位置
	var spawn_offset = Vector2(
		throw_direction.x * THROW_OFFSET_X,
		THROW_OFFSET_Y
	)
	var spawn_position = global_position + spawn_offset

	# 初始化炸弹
	bomb.initialize(
		spawn_position,           # 初始位置
		target.global_position,    # 目标位置
		CONFIG.throw_damage,       # 伤害值
		CONFIG.explosion_radius    # 爆炸半径
	)

func _on_animation_finished() -> void:
	if animated_sprite.animation == "throw":
		change_state(TntState.IDLE)

func on_state_enter(new_state: int, _old_state: int) -> void:
	match new_state:
		TntState.IDLE:
			play_idle_animation()
		TntState.RUNNING:
			animated_sprite.play("run")
		TntState.THROWING:
			animated_sprite.play("throw")
			throw_tnt()
		TntState.DEAD:
			# 播放死亡动画或特效
			queue_free()
