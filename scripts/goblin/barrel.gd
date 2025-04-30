# @file: barrel.gd
# @brief: 哥布林桶兵脚本
# @author: ponywu

extends GoblinBase

# 扩展状态
enum BarrelState {
	IDLE = BaseState.IDLE,    # 继承基类状态
	RUNNING = BaseState.RUNNING,
	DEAD = BaseState.DEAD,
	HIDING = 10,              # 自定义状态从10开始避免冲突
	JUMPING,
	LOOKING,
	EXPLODING
}

# 桶兵特有的变量
var exploded: bool = false

func _ready() -> void:
	# 配置参数
	CONFIG = {
		"move_speed": 100.0,      # 移动速度
		"health": 50,             # 生命值
		"detection_radius": 150,  # 检测半径
		"explosion_damage": 30,   # 爆炸伤害
		"explosion_radius": 100,  # 爆炸伤害半径
		"attack_interval": 1.0,   # 攻击检测间隔
	}

	super._ready()

func initialize() -> void:
	super.initialize()
	animated_sprite.play("close")

func process_state(_delta: float) -> void:
	match current_state:
		BarrelState.IDLE:
			pass
		BarrelState.RUNNING:
			if move_direction.length() < 0.1:
				change_state(BarrelState.IDLE)
		BarrelState.HIDING:
			pass
		BarrelState.JUMPING:
			pass
		BarrelState.LOOKING:
			pass
		BarrelState.EXPLODING:
			pass

func _physics_process(_delta: float) -> void:
	# 如果在爆炸或隐藏状态，不移动
	if current_state == BarrelState.EXPLODING or current_state == BarrelState.HIDING:
		velocity = Vector2.ZERO
		return

	# 如果有目标，向目标移动
	if target and current_state == BarrelState.RUNNING:
		move_direction = (target.global_position - global_position).normalized()
		velocity = move_direction * CONFIG.move_speed

		# 如果靠近目标，爆炸攻击
		if global_position.distance_to(target.global_position) < CONFIG.explosion_radius * 0.7:
			change_state(BarrelState.EXPLODING)
	else:
		# 否则按当前移动方向移动
		velocity = move_direction * CONFIG.move_speed

		# 如果速度很小，视为静止
		if velocity.length() < 10:
			velocity = Vector2.ZERO
			if current_state == BarrelState.RUNNING:
				change_state(BarrelState.IDLE)

	# 应用移动
	move_and_slide()

func _random_action() -> void:
	# 如果已经有目标，不执行随机行为
	if target != null:
		return

	var action = randi() % 10

	match action:
		0, 1:
			# 看看周围
			change_state(BarrelState.LOOKING)
			# 短暂后回到待机
			await get_tree().create_timer(1.0).timeout
			change_state(BarrelState.IDLE)
		2, 3, 4:
			# 随机移动
			move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			change_state(BarrelState.RUNNING)
			# 移动一段时间后停下
			await get_tree().create_timer(randf_range(1.0, 3.0)).timeout
			move_direction = Vector2.ZERO
		5:
			# 隐藏一下
			change_state(BarrelState.HIDING)
			await get_tree().create_timer(2.0).timeout
			change_state(BarrelState.IDLE)
		6:
			# 跳跃
			change_state(BarrelState.JUMPING)
			await animated_sprite.animation_finished
			change_state(BarrelState.IDLE)
		_:
			# 待机
			change_state(BarrelState.IDLE)

func on_state_enter(new_state: int, _old_state: int) -> void:
	match new_state:
		BarrelState.IDLE:
			animated_sprite.play("close")
		BarrelState.RUNNING:
			animated_sprite.play("run")
		BarrelState.HIDING:
			animated_sprite.play("hide")
		BarrelState.JUMPING:
			animated_sprite.play("jump")
		BarrelState.LOOKING:
			animated_sprite.play("look")
		BarrelState.EXPLODING:
			animated_sprite.play("explode")
			explode()
		BarrelState.DEAD:
			change_state(BarrelState.EXPLODING)  # 桶兵死亡时爆炸

func explode() -> void:
	if exploded:
		return

	exploded = true

	# 对爆炸范围内的目标造成伤害
	var targets = get_tree().get_nodes_in_group("player_units")
	for t in targets:
		var distance = global_position.distance_to(t.global_position)
		if distance <= CONFIG.explosion_radius:
			if t.has_method("take_damage"):
				# 伤害随距离衰减
				var damage_factor = 1.0 - (distance / CONFIG.explosion_radius)
				var actual_damage = int(CONFIG.explosion_damage * damage_factor)
				t.take_damage(actual_damage)

	# 对建筑造成伤害
	var buildings = get_tree().get_nodes_in_group("player_buildings")
	for building in buildings:
		var distance = global_position.distance_to(building.global_position)
		if distance <= CONFIG.explosion_radius:
			if building.has_method("take_damage"):
				# 伤害随距离衰减
				var damage_factor = 1.0 - (distance / CONFIG.explosion_radius)
				var actual_damage = int(CONFIG.explosion_damage * damage_factor)
				building.take_damage(actual_damage)

	# 爆炸效果
	print("爆炸桶爆炸了！")

	# 爆炸后销毁
	await animated_sprite.animation_finished
	queue_free()

func handle_death() -> void:
	change_state(BarrelState.EXPLODING)

func play_idle_animation() -> void:
	animated_sprite.play("close")
