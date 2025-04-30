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

# TNT炸弹场景
var tnt_bomb_scene: PackedScene = null  # 实际项目中需要加载具体场景

func _ready() -> void:
	# 配置参数
	CONFIG = {
		"move_speed": 90.0,       # 移动速度
		"health": 40,             # 生命值
		"detection_radius": 180,  # 检测半径
		"throw_range": 150,       # 投掷范围
		"throw_damage": 25,       # 投掷伤害
		"explosion_radius": 80,   # 爆炸伤害半径
		"attack_interval": 1.0,   # 攻击检测间隔
	}

	# 调用父类的_ready函数
	super._ready()

	# 监听动画完成事件
	animated_sprite.animation_finished.connect(_on_animation_finished)

func initialize() -> void:
	super.initialize()
	# 初始化特定变量
	can_throw = true
	throw_cooldown = 0.0

func play_idle_animation() -> void:
	animated_sprite.play("idle")

func handle_attack() -> void:
	# TNT哥布林在攻击距离内会投掷TNT
	if can_throw:
		change_state(TntState.THROWING)

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

	match current_state:
		TntState.IDLE:
			# 如果有目标并且在检测范围内，追击目标
			if target and global_position.distance_to(target.global_position) < CONFIG.detection_radius:
				change_state(TntState.RUNNING)

		TntState.RUNNING:
			if target:
				var distance = global_position.distance_to(target.global_position)
				# 如果距离太近，尝试拉开距离
				if distance < CONFIG.throw_range * 0.5:
					move_direction = (global_position - target.global_position).normalized()
				# 在投掷范围内且可以投掷，进行投掷
				elif distance < CONFIG.throw_range and can_throw:
					change_state(TntState.THROWING)
				# 否则继续追击
				else:
					move_direction = (target.global_position - global_position).normalized()
			else:
				# 没有目标时，随机移动或回到待机
				if move_direction.length() < 0.1:
					change_state(TntState.IDLE)

		TntState.THROWING:
			# 投掷动画中，不移动
			pass

		TntState.DEAD:
			# 死亡状态
			pass

func _physics_process(_delta: float) -> void:
	# 如果在投掷或死亡状态，不移动
	if current_state == TntState.THROWING or current_state == TntState.DEAD:
		velocity = Vector2.ZERO
		return

	# 应用移动
	velocity = move_direction * CONFIG.move_speed
	move_and_slide()

func _random_action() -> void:
	# 如果已经有目标，不执行随机行为
	if target != null:
		return

	var action = randi() % 5

	match action:
		0, 1:
			# 随机移动
			move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			change_state(TntState.RUNNING)
			# 移动一段时间后停下
			await get_tree().create_timer(randf_range(1.0, 2.0)).timeout
			move_direction = Vector2.ZERO
		_:
			# 待机
			change_state(TntState.IDLE)

func on_state_enter(new_state: int, _old_state: int) -> void:
	match new_state:
		TntState.IDLE:
			animated_sprite.play("idle")
		TntState.RUNNING:
			animated_sprite.play("run")
		TntState.THROWING:
			animated_sprite.play("throw")
			throw_tnt()
		TntState.DEAD:
			# 播放死亡动画或特效
			queue_free()

func throw_tnt() -> void:
	if !can_throw or !target:
		return

	can_throw = false

	# 实际投掷逻辑将在动画的特定帧触发
	print("TNT哥布林准备投掷!")

func spawn_and_throw_tnt() -> void:
	if !target:
		return

	print("TNT哥布林投掷了炸弹!")

	# 这里将实际生成TNT炸弹并设置其属性
	# 如果有TNT炸弹场景，则实例化并发射
	if tnt_bomb_scene:
		var bomb = tnt_bomb_scene.instantiate()
		bomb.global_position = global_position

		# 设置炸弹属性
		var throw_direction = (target.global_position - global_position).normalized()
		if bomb.has_method("initialize"):
			bomb.initialize(throw_direction, CONFIG.throw_damage, global_position, target.global_position)

		# 将炸弹添加到场景
		get_tree().root.add_child(bomb)

func _on_animation_finished() -> void:
	if animated_sprite.animation == "throw":
		change_state(TntState.IDLE)
