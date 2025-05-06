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

var exploded: bool = false

func _ready() -> void:
	# 配置参数
	CONFIG = {
		"move_speed": 50.0,       # 移动速度
		"health": 50,              # 生命值
		"detection_radius": 80,   # 检测半径
		"explosion_damage": 20,    # 爆炸伤害
		"explosion_radius": 100,   # 爆炸伤害半径
		"attack_interval": 1.0,    # 攻击检测间隔
		"attack_distance": 100.0,   # 攻击距离
	}

	super._ready()
	# 监听动画帧变化事件
	animated_sprite.frame_changed.connect(_on_frame_changed)

func initialize() -> void:
	super.initialize()
	animated_sprite.play("close")

func process_state(_delta: float) -> void:
	# 检查是否有目标在爆炸范围内
	if current_state != BarrelState.EXPLODING and current_state != BarrelState.DEAD:
		var nearby_targets = get_tree().get_nodes_in_group("soldiers") + get_tree().get_nodes_in_group("buildings")
		for t in nearby_targets:
			if is_instance_valid(t):
				var distance = global_position.distance_to(t.global_position)
				if distance <= CONFIG.detection_radius:
					print("检测到目标在爆炸范围内！")
					change_state(BarrelState.EXPLODING)
					return

	print("当前状态：", current_state)
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

func handle_attack() -> void:
	# 桶兵在攻击距离内会爆炸
	change_state(BarrelState.EXPLODING)

func _physics_process(_delta: float) -> void:
	# 如果在爆炸或隐藏状态，不移动
	if current_state == BarrelState.EXPLODING or current_state == BarrelState.HIDING:
		velocity = Vector2.ZERO
		return

	super._physics_process(_delta)

func _random_action() -> void:
	# 如果已经有目标，不执行随机行为
	if target != null:
		return

	var action = randi() % 10
	print("火药桶随机行为：", action)

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
	animated_sprite.play("explode")
	await animated_sprite.animation_finished
	queue_free()

func _on_frame_changed() -> void:
	if animated_sprite.animation == "explode":
		# 获取当前动画的总帧数
		var total_frames = animated_sprite.sprite_frames.get_frame_count(animated_sprite.animation)
		# 在倒数第二帧触发伤害
		if animated_sprite.frame == total_frames - 6:
			explode_damage("soldiers")
			explode_damage("buildings")

func _on_animation_finished() -> void:
	if animated_sprite.animation == "explode":
		queue_free()

func explode_damage(group_name: String) -> void:
	var targets = get_tree().get_nodes_in_group(group_name)
	for t in targets:
		if is_instance_valid(t):  # 确保目标还存在
			var distance = global_position.distance_to(t.global_position)
			if distance <= CONFIG.explosion_radius:
				if t.has_method("take_damage"):
					var damage_factor = 1.0 - (distance / CONFIG.explosion_radius)
					var actual_damage = int(CONFIG.explosion_damage * damage_factor)
					t.take_damage(actual_damage)

func handle_death() -> void:
	change_state(BarrelState.EXPLODING)

func play_idle_animation() -> void:
	animated_sprite.play("close")
