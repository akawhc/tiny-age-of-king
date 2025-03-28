extends CharacterBody2D

# 移动相关常量
const MOVE_SPEED = 150
const ATTACK_RANGE = 100

# 攻击相关常量
const ATTACK_CONFIG = {
	"slight": {
		"animation": "side_attack_slight",
		"damage": 20,
		"hit_frame": 4  # 在第2帧检测伤害
	},
	"heavy": {
		"animation": "side_attack_heavy",
		"damage": 30,  # 1.5倍于slight攻击
		"hit_frame": 4  # 在第2帧检测伤害
	}
}

# 动画状态
const ANIMATION_STATES = {
	"IDLE": "idle",
	"RUN": "run"
}

@onready var animated_sprite_2d = $AnimatedSprite2D

var wood_count = 0  # 木材数量
var nearest_tree = null  # 最近的树
var is_attacking = false  # 是否正在攻击
var facing_direction = Vector2.RIGHT  # 角色朝向
var current_attack = "slight"  # 当前攻击类型
var has_hit = false  # 是否已经造成伤害

func _ready() -> void:
	add_to_group("players")  # 添加到玩家组，用于树木和木材的交互
	animated_sprite_2d.play(ANIMATION_STATES.IDLE)  # 初始状态为待机
	animated_sprite_2d.frame_changed.connect(_on_animation_frame_changed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("chop") and not is_attacking:
		start_attack()

func _physics_process(_delta: float) -> void:
	var direction = Vector2.ZERO
	direction.x = Input.get_axis("ui_left", "ui_right")
	direction.y = Input.get_axis("ui_up", "ui_down")

	if direction:
		velocity = direction.normalized() * MOVE_SPEED
		# 更新朝向
		if direction.x != 0:
			facing_direction = Vector2(sign(direction.x), 0)
			if not is_attacking:
				animated_sprite_2d.flip_h = direction.x < 0
	else:
		velocity = Vector2.ZERO

	# 更新动画
	if not is_attacking:
		set_animation_state()

	move_and_slide()

func _on_animation_frame_changed() -> void:
	if is_attacking and not has_hit:
		var current_frame = animated_sprite_2d.frame
		if current_frame == ATTACK_CONFIG[current_attack]["hit_frame"]:
			check_tree_hit()
			has_hit = true

func start_attack() -> void:
	is_attacking = true
	has_hit = false

	# 根据朝向设置动画翻转
	animated_sprite_2d.flip_h = facing_direction.x < 0

	# 播放当前攻击动画
	animated_sprite_2d.play(ATTACK_CONFIG[current_attack]["animation"])

	# 切换下一次攻击类型
	current_attack = "heavy" if current_attack == "slight" else "slight"

	# 等待动画播放完成
	await animated_sprite_2d.animation_finished

	# 恢复到之前的状态
	is_attacking = false
	set_animation_state()

func set_animation_state() -> void:
	if velocity.length() > 0:
		animated_sprite_2d.play(ANIMATION_STATES.RUN)
	else:
		animated_sprite_2d.play(ANIMATION_STATES.IDLE)

func check_tree_hit() -> void:
	# 检查攻击范围内是否有树
	var space_state = get_world_2d().direct_space_state
	var attack_direction = Vector2.RIGHT if not animated_sprite_2d.flip_h else Vector2.LEFT
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + attack_direction * ATTACK_RANGE
	)
	query.collide_with_areas = true
	var result = space_state.intersect_ray(query)

	if result and "collider" in result:
		var collider = result.collider
		if collider.get_parent() is AnimatedSprite2D and collider.get_parent().is_in_group("trees"):
			var damage = ATTACK_CONFIG[current_attack]["damage"]
			collider.get_parent().take_damage(damage)

# 收集木材
func collect_wood() -> void:
	wood_count += 1
	print("骑士收集到木材！当前数量：", wood_count)

# 设置最近的树
func set_nearest_tree(tree) -> void:
	nearest_tree = tree
