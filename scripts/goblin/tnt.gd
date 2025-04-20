# @file: tnt.gd
# @brief: TNT哥布林脚本
# @author: ponywu

extends CharacterBody2D

# 配置参数
const CONFIG = {
	"move_speed": 90.0,       # 移动速度
	"health": 40,             # 生命值
	"detection_radius": 180,  # 检测半径
	"throw_range": 150,       # 投掷范围
	"throw_damage": 25,       # 投掷伤害
	"explosion_radius": 80,   # 爆炸伤害半径
}

# 状态
enum State {
	IDLE,       # 待机
	RUNNING,    # 奔跑
	THROWING,   # 投掷
	DEAD        # 死亡
}

# 变量
var current_state: State = State.IDLE
var health: int = CONFIG.health
var target: Node2D = null
var move_direction: Vector2 = Vector2.ZERO
var throw_cooldown: float = 0.0
var can_throw: bool = true
var throw_cooldown_time: float = 3.0
var random_timer: float = 0.0
var random_move_cooldown: float = 3.0

# 节点引用
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# TNT炸弹场景
var tnt_bomb_scene: PackedScene = null  # 实际项目中需要加载具体场景

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
	# 投掷冷却
	if !can_throw:
		throw_cooldown += delta
		if throw_cooldown >= throw_cooldown_time:
			throw_cooldown = 0.0
			can_throw = true

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
				# 如果距离太近，尝试拉开距离
				if distance < CONFIG.throw_range * 0.5:
					move_direction = (global_position - target.global_position).normalized()
				# 在投掷范围内且可以投掷，进行投掷
				elif distance < CONFIG.throw_range and can_throw:
					change_state(State.THROWING)
				# 否则继续追击
				else:
					move_direction = (target.global_position - global_position).normalized()
			else:
				# 没有目标时，随机移动或回到待机
				if move_direction.length() < 0.1:
					change_state(State.IDLE)

		State.THROWING:
			# 投掷动画中，不移动
			pass

		State.DEAD:
			# 死亡状态
			pass

func _physics_process(delta: float) -> void:
	# 如果在投掷或死亡状态，不移动
	if current_state == State.THROWING or current_state == State.DEAD:
		velocity = Vector2.ZERO
		return

	# 应用移动
	velocity = move_direction * CONFIG.move_speed
	move_and_slide()

# 随机行为
func _random_action() -> void:
	var action = randi() % 5

	match action:
		0, 1:
			# 随机移动
			move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
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
		State.THROWING:
			animated_sprite.play("throw")
			throw_tnt()
		State.DEAD:
			# 播放死亡动画或特效
			queue_free()

# 投掷TNT
func throw_tnt() -> void:
	if !can_throw or !target:
		return

	can_throw = false

	# 实际投掷逻辑将在动画的特定帧触发
	print("TNT哥布林准备投掷!")

# 在特定动画帧实际生成并投掷TNT
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

# 动画完成回调
func _on_animation_finished() -> void:
	if animated_sprite.animation == "throw":
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