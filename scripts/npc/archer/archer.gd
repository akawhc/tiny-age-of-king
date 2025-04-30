# @file: archer.gd
# @brief: 弓箭手单位脚本
# @date: 2025-04-20
# @author: ponywu

extends "res://scripts/units/selectable_unit.gd"

# 弓箭手配置
const ARCHER_CONFIG = {
	"detection_radius": 200.0,  # 检测半径
	"attack_damage": 15,        # 攻击伤害
	"move_speed": 75.0,         # 移动速度
	"attack_cooldown": 2.0,     # 攻击冷却时间(秒)
	"arrow_speed": 300.0,       # 箭矢速度
}

# 弓箭手状态
enum ArcherState {
	IDLE,
	ATTACKING,
	MOVING
}

# 当前状态 (基本移动状态由父类处理)
var current_state: ArcherState = ArcherState.IDLE

# 攻击相关
var target_enemy: Node2D = null
var attack_cooldown_timer: float = 0.0
var can_attack: bool = true
var facing_direction = Vector2.RIGHT
var auto_attack: bool = true  # 是否自动攻击，可以在UI中设置

# 箭矢场景路径
var arrow_scene_path: String = "res://scenes/projectiles/arrow.tscn"

# 节点引用
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var arrow_spawn_point: Marker2D = $ArrowSpawnPoint

# 新增变量
var enemies_in_range: Array = []

func _ready() -> void:
	super._ready()

	add_to_group("archers")
	add_to_group("soldiers")

	# 覆盖父类的默认移动速度
	move_speed = ARCHER_CONFIG.move_speed

	# 初始化检测区域
	var detection_shape = detection_area.get_node_or_null("CollisionShape2D")
	if detection_shape:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = ARCHER_CONFIG.detection_radius
		detection_shape.shape = circle_shape

	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	animated_sprite.animation_finished.connect(_on_animation_finished)

	play_idle_animation()

func _input(event: InputEvent) -> void:
	# 只有被选中的单位才响应按键输入
	if !is_selected:
		return

	# 如果正在攻击，不处理攻击输入，但可以继续移动
	if current_state == ArcherState.ATTACKING and event.is_action_pressed("chop"):
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("chop"):
		get_viewport().set_input_as_handled()

		if !can_attack:
			print("弓箭手正在冷却中，无法攻击")
			return

		if target_enemy:
			start_attack()
		else:
			manual_shoot()

func _process(delta: float) -> void:
	# 处理攻击冷却
	if !can_attack:
		attack_cooldown_timer += delta
		if attack_cooldown_timer >= ARCHER_CONFIG.attack_cooldown:
			can_attack = true
			attack_cooldown_timer = 0.0

	# 如果有敌人目标且可以攻击，则开始攻击
	if target_enemy and can_attack and current_state != ArcherState.ATTACKING:
		start_attack()

# 覆盖父类的physics_process，调整自己的攻击逻辑
func _physics_process(delta: float) -> void:
	# 允许在攻击时也能移动，不再锁定速度
	# 调用父类方法处理移动和键盘输入
	super._physics_process(delta)

	# 如果有移动，更新朝向
	if velocity.length() > 0:
		if velocity.x != 0:
			facing_direction = Vector2(sign(velocity.x), 0)
			animated_sprite.flip_h = velocity.x < 0

		# 只有在不攻击时才更新状态和动画
		if current_state != ArcherState.ATTACKING:
			current_state = ArcherState.MOVING
			animated_sprite.play("run")
	else:
		# 只有在不攻击时才更新状态和动画
		if current_state != ArcherState.ATTACKING:
			current_state = ArcherState.IDLE
			play_idle_animation()

func _on_detection_area_body_entered(body: Node2D) -> void:
	# 检测进入范围的敌人
	if body.is_in_group("goblin"):
		enemies_in_range.append(body)
		update_target()

func _on_detection_area_body_exited(body: Node2D) -> void:
	# 敌人离开检测范围
	if body.is_in_group("goblin"):
		if enemies_in_range.has(body):
			enemies_in_range.erase(body)
		if body == target_enemy:
			target_enemy = null
		update_target()

# 更新目标敌人为最近的哥布林
func update_target() -> void:
	var closest_enemy = null
	var closest_distance = INF

	for enemy in enemies_in_range:
		if is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy

	target_enemy = closest_enemy

func start_attack() -> void:
	if current_state == ArcherState.ATTACKING:
		return

	current_state = ArcherState.ATTACKING
	can_attack = false

	var attack_direction = (target_enemy.global_position - global_position).normalized()
	play_attack_animation(attack_direction)

# 手动射击
func manual_shoot() -> void:
	if current_state == ArcherState.ATTACKING:
		return

	current_state = ArcherState.ATTACKING
	can_attack = false

	# 使用当前朝向作为射击方向
	var shoot_direction = facing_direction
	if animated_sprite.flip_h:
		shoot_direction = Vector2(-1, 0)  # 如果精灵翻转，则向左射击

	play_attack_animation(shoot_direction)

func play_attack_animation(direction: Vector2) -> void:
	# 根据攻击方向选择合适的射击动画
	var animation_name = "shoot_right_normal"

	# 根据方向确定动画并设置朝向
	if abs(direction.x) > abs(direction.y):
		# 水平方向射击
		animated_sprite.flip_h = direction.x < 0
		animation_name = "shoot_right_normal"
	else:
		# 垂直方向射击
		if direction.y > 0:
			animation_name = "shoot_down"
			animated_sprite.flip_h = false
		else:
			animation_name = "shoot_up"
			animated_sprite.flip_h = false

	# 对角线方向的处理
	if abs(direction.x) > 0.3 and abs(direction.y) > 0.3:
		if direction.x > 0:
			animated_sprite.flip_h = false
			if direction.y > 0:
				animation_name = "shoot_right_down"
			else:
				animation_name = "shoot_right_up"
		else:
			animated_sprite.flip_h = true
			if direction.y > 0:
				animation_name = "shoot_right_down"
			else:
				animation_name = "shoot_right_up"

	# 播放动画
	animated_sprite.play(animation_name)

func _on_animation_finished() -> void:
	var animation_name = animated_sprite.animation

	# 如果是射击动画完成，则生成箭矢并返回到IDLE状态
	if animation_name.begins_with("shoot_"):
		shoot_arrow()
		current_state = ArcherState.IDLE

		# 根据当前速度更新动画状态
		if velocity.length() > 0:
			animated_sprite.play("run")
			current_state = ArcherState.MOVING
		else:
			play_idle_animation()

func shoot_arrow() -> void:
	var shoot_direction

	# 如果目标存在，则朝目标射击
	if target_enemy:
		shoot_direction = (target_enemy.global_position - global_position).normalized()
	else:
		shoot_direction = facing_direction
		if animated_sprite.flip_h:
			shoot_direction = Vector2(-1, 0)

	# 加载箭矢场景
	var arrow_scene = load(arrow_scene_path)
	if arrow_scene:
		var arrow_instance = arrow_scene.instantiate()

		# 设置箭矢参数
		arrow_instance.global_position = arrow_spawn_point.global_position

		# 使用箭矢的initialize方法初始化
		arrow_instance.initialize(
			shoot_direction,
			ARCHER_CONFIG.attack_damage,
			ARCHER_CONFIG.arrow_speed,
			self
		)

		# 将箭矢添加到场景
		get_tree().get_root().add_child(arrow_instance)
	else:
		print("ERROR: 无法加载箭矢场景!")

func play_idle_animation() -> void:
	if current_state != ArcherState.ATTACKING:
		animated_sprite.play("idle")

func update_animation(direction: Vector2) -> void:
	# 如果正在攻击，不更新移动动画
	if current_state == ArcherState.ATTACKING:
		return

	if direction.x != 0:
		facing_direction = Vector2(sign(direction.x), 0)
		animated_sprite.flip_h = direction.x < 0

	if direction.length() > 0:
		animated_sprite.play("run")
	else:
		play_idle_animation()
