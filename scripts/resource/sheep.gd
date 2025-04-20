# @file: sheep.gd
# @brief: 绵羊行为脚本
# @author: ponywu

extends CharacterBody2D

# 绵羊相关常量
const SHEEP_CONFIG = {
	"health": {
		"max": 100,             # 最大生命值
		"hit_flash_time": 0.2,  # 受击闪烁时间
	},
	"movement": {
		"speed": 20,         # 移动速度
		"wander_radius": 100,  # 游荡半径
		"direction_change_time": {
			"min": 4.0,      # 最小方向变化时间
			"max": 8.0       # 最大方向变化时间
		},
		"idle_time": {
			"min": 3.0,      # 最小静止时间
			"max": 6.0       # 最大静止时间
		}
	},
	"death": {
		"meat_drop": {
			"min": 2,        # 最小掉落肉数量
			"max": 4,        # 最大掉落肉数量
			"spread_radius": 20  # 肉掉落散布半径
		}
	},
	"animation": {
		"idle_chance": 0.6   # 静止动画的概率
	}
}

# 状态枚举
enum SheepState {
	IDLE,     # 静止状态
	MOVING,   # 移动状态
	HURT,     # 受伤状态
	DEAD      # 死亡状态
}

# 绵羊状态
var current_state: SheepState = SheepState.IDLE
var current_health: int = SHEEP_CONFIG.health.max
var spawn_position: Vector2  # 出生位置，用于限制游荡范围
var move_direction: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var next_state_change: float = 0.0
var is_dead: bool = false  # 是否死亡的标记

# 节点引用
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
# 预加载肉资源场景
@onready var meat_scene = preload("res://scenes/resources/meat.tscn")

func _ready() -> void:
	add_to_group("animals")
	add_to_group("attackable")  # 添加到可攻击组，让工人能攻击绵羊
	spawn_position = global_position
	current_health = SHEEP_CONFIG.health.max

	# 确保碰撞设置正确
	collision_shape.set_deferred("disabled", false)

	# 确保检测区域的碰撞掩码和层设置正确
	if has_node("DetectionArea"):
		var detection_area = get_node("DetectionArea")
		detection_area.collision_mask = 1  # 确保可以检测到工人
		detection_area.collision_layer = 2  # 设置成与工人不同的层
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)

	# 初始状态设置
	_change_state(SheepState.IDLE)
	_pick_random_movement_time()

func _process(delta: float) -> void:
	match current_state:
		SheepState.IDLE:
			_process_idle_state(delta)
		SheepState.MOVING:
			_process_moving_state(delta)
		SheepState.HURT:
			_process_hurt_state(delta)
		SheepState.DEAD:
			# 死亡状态不需要处理任何逻辑
			pass

func _physics_process(_delta: float) -> void:
	if current_state == SheepState.MOVING:
		velocity = move_direction * SHEEP_CONFIG.movement.speed
		move_and_slide()

# 处理静止状态
func _process_idle_state(delta: float) -> void:
	state_timer += delta
	if state_timer >= next_state_change:
		# 时间到，切换到移动状态
		_change_state(SheepState.MOVING)
		_pick_random_movement_time()

# 处理移动状态
func _process_moving_state(delta: float) -> void:
	state_timer += delta
	if state_timer >= next_state_change:
		# 时间到，有概率切换到静止状态
		if randf() < SHEEP_CONFIG.animation.idle_chance:
			_change_state(SheepState.IDLE)
		else:
			# 继续移动，但改变方向
			_pick_new_direction()
		_pick_random_movement_time()

# 处理受伤状态
func _process_hurt_state(delta: float) -> void:
	state_timer += delta
	if state_timer >= SHEEP_CONFIG.health.hit_flash_time:
		# 受伤闪烁结束，返回之前的状态
		if current_health <= 0:
			_change_state(SheepState.DEAD)
			_die()
		else:
			_change_state(SheepState.IDLE)

# 切换状态
func _change_state(new_state: SheepState) -> void:
	current_state = new_state
	state_timer = 0.0

	match new_state:
		SheepState.IDLE:
			animated_sprite.play("idle")
			move_direction = Vector2.ZERO
			velocity = Vector2.ZERO
		SheepState.MOVING:
			animated_sprite.play("bouncing")
			_pick_new_direction()
		SheepState.HURT:
			# 闪烁效果
			var hurt_tween = create_tween()
			hurt_tween.tween_property(animated_sprite, "modulate", Color(1, 0.3, 0.3, 0.7), 0.1)
			hurt_tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1), 0.1)
		SheepState.DEAD:
			# 死亡状态的设置
			animated_sprite.stop()
			# 闪烁然后淡出
			var death_tween = create_tween()
			death_tween.tween_property(animated_sprite, "modulate", Color(1, 0, 0, 0.7), 0.2)
			death_tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 0), 0.3)
			death_tween.tween_callback(queue_free)  # 动画结束后删除实例

# 选择新的随机移动方向
func _pick_new_direction() -> void:
	# 计算一个指向出生点的方向向量，用于限制绵羊不会走太远
	var to_spawn = spawn_position - global_position
	var distance_to_spawn = to_spawn.length()

	if distance_to_spawn > SHEEP_CONFIG.movement.wander_radius:
		# 如果距离出生点太远，有70%的概率往回走
		if randf() < 0.7:
			move_direction = to_spawn.normalized()
		else:
			move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	else:
		# 在游荡范围内，随机选择方向
		move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

	# 根据移动方向设置精灵朝向
	if move_direction.x < 0:
		animated_sprite.flip_h = true
	elif move_direction.x > 0:
		animated_sprite.flip_h = false

# 选择随机状态持续时间
func _pick_random_movement_time() -> void:
	if current_state == SheepState.IDLE:
		next_state_change = randf_range(
			SHEEP_CONFIG.movement.idle_time.min,
			SHEEP_CONFIG.movement.idle_time.max
		)
	else:
		next_state_change = randf_range(
			SHEEP_CONFIG.movement.direction_change_time.min,
			SHEEP_CONFIG.movement.direction_change_time.max
		)

# 受到攻击
func take_damage(damage: int) -> void:
	if current_state == SheepState.DEAD or is_dead:
		return

	current_health -= damage
	_change_state(SheepState.HURT)

	# 播放受击动画
	var hit_effect = create_tween()
	hit_effect.tween_property(self, "position", position + Vector2(randf_range(-5, 5), randf_range(-5, 5)), 0.1)
	hit_effect.tween_property(self, "position", position, 0.1)

# 死亡处理
func _die() -> void:
	is_dead = true  # 设置死亡标记
	# 禁用碰撞
	collision_shape.set_deferred("disabled", true)

	# 随机确定掉落的肉数量
	var meat_count = randi_range(
		SHEEP_CONFIG.death.meat_drop.min,
		SHEEP_CONFIG.death.meat_drop.max
	)

	# 掉落肉
	_drop_meat(meat_count)

# 掉落肉资源
func _drop_meat(count: int) -> void:
	var spread_radius = SHEEP_CONFIG.death.meat_drop.spread_radius

	for i in range(count):
		# 创建肉实例
		var meat_instance = meat_scene.instantiate()

		# 随机位置，在绵羊周围的圆形区域内
		var random_angle = randf() * 2 * PI
		var random_distance = randf() * spread_radius
		var spawn_offset = Vector2(cos(random_angle), sin(random_angle)) * random_distance

		# 设置肉的位置
		meat_instance.position = global_position + spawn_offset

		# 将肉添加到场景中
		get_tree().get_root().add_child(meat_instance)

# 当工人进入检测范围
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("workers"):
		if body.has_method("set_nearest_animal"):
			body.set_nearest_animal(self)

# 当工人离开检测范围
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("workers"):
		if body.has_method("set_nearest_animal") and body.nearest_animal == self:
			body.set_nearest_animal(null)