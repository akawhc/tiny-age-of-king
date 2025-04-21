# @file: barrel.gd
# @brief: 哥布林桶兵脚本
# @author: ponywu

extends CharacterBody2D

# 配置参数
const CONFIG = {
	"move_speed": 100.0,      # 移动速度
	"health": 50,             # 生命值
	"detection_radius": 150,  # 检测半径
	"explosion_damage": 30,   # 爆炸伤害
	"explosion_radius": 100,  # 爆炸伤害半径
}

# 状态
enum State {
	IDLE,      # 待机
	RUNNING,   # 奔跑
	HIDING,    # 隐藏
	JUMPING,   # 跳跃
	LOOKING,   # 观察
	EXPLODING  # 爆炸
}

# 变量
var current_state: State = State.IDLE
var health: int = CONFIG.health
var target: Node2D = null
var move_direction: Vector2 = Vector2.ZERO
var exploded: bool = false
var random_timer: float = 0.0
var random_move_cooldown: float = 3.0

# 节点引用
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# 添加到敌人组
	add_to_group("enemies")

	# 初始化
	animated_sprite.play("close")

	# 生成随机移动间隔
	randomize()
	random_move_cooldown = randf_range(2.0, 5.0)

func _process(delta: float) -> void:
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
			pass
		State.RUNNING:
			if move_direction.length() < 0.1:
				change_state(State.IDLE)
		State.HIDING:
			pass
		State.JUMPING:
			pass
		State.LOOKING:
			pass
		State.EXPLODING:
			pass

func _physics_process(_delta: float) -> void:
	# 如果在爆炸或隐藏状态，不移动
	if current_state == State.EXPLODING or current_state == State.HIDING:
		velocity = Vector2.ZERO
		return

	# 如果有目标，向目标移动
	if target and current_state == State.RUNNING:
		move_direction = (target.global_position - global_position).normalized()
		velocity = move_direction * CONFIG.move_speed
	else:
		# 否则按当前移动方向移动
		velocity = move_direction * CONFIG.move_speed

		# 如果速度很小，视为静止
		if velocity.length() < 10:
			velocity = Vector2.ZERO
			if current_state == State.RUNNING:
				change_state(State.IDLE)

	# 应用移动
	move_and_slide()

# 随机行为
func _random_action() -> void:
	var action = randi() % 10

	match action:
		0, 1:
			# 看看周围
			change_state(State.LOOKING)
			# 短暂后回到待机
			await get_tree().create_timer(1.0).timeout
			change_state(State.IDLE)
		2, 3, 4:
			# 随机移动
			move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			change_state(State.RUNNING)
			# 移动一段时间后停下
			await get_tree().create_timer(randf_range(1.0, 3.0)).timeout
			move_direction = Vector2.ZERO
		5:
			# 隐藏一下
			change_state(State.HIDING)
			await get_tree().create_timer(2.0).timeout
			change_state(State.IDLE)
		6:
			# 跳跃
			change_state(State.JUMPING)
			await animated_sprite.animation_finished
			change_state(State.IDLE)
		_:
			# 待机
			change_state(State.IDLE)

# 改变状态
func change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	# 退出当前状态
	match current_state:
		State.EXPLODING:
			# 已经爆炸则不能改变状态
			return

	# 进入新状态
	current_state = new_state

	match new_state:
		State.IDLE:
			animated_sprite.play("close")
		State.RUNNING:
			animated_sprite.play("run")
		State.HIDING:
			animated_sprite.play("hide")
		State.JUMPING:
			animated_sprite.play("jump")
		State.LOOKING:
			animated_sprite.play("look")
		State.EXPLODING:
			animated_sprite.play("explode")
			explode()

# 爆炸
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

	# 爆炸效果
	print("爆炸桶爆炸了！")

	# 爆炸后销毁
	await animated_sprite.animation_finished
	queue_free()

# 受到伤害
func take_damage(damage: int) -> void:
	health -= damage

	if health <= 0:
		change_state(State.EXPLODING)
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