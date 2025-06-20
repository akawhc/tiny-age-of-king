# file: knight.gd
# author: ponywu
# date: 2024-03-24
# description: 骑士单位脚本

extends "res://scripts/units/selectable_unit.gd"


# 骑士配置
const KNIGHT_CONFIG = {
	"detection_radius": 150.0,  # 检测半径
	"attack_range": 120.0,      # 攻击范围
	"move_speed": 200.0,       # 移动速度
	"attack_cooldown": 1.0,    # 攻击冷却时间(秒)
	"auto_attack_cooldown": 0.8, # 自动攻击的额外冷却时间(秒) - 减少冷却时间
}

# 骑士状态
enum KnightState {
	IDLE,
	MOVING,
	ATTACKING,
	COMBO_WINDOW
}

# 移动方向
enum FacingDirection {
	UP,
	DOWN,
	RIGHT,
	LEFT
}

# 动画状态
const ANIMATION_STATES = {
	"IDLE": "idle",
	"RUN": "run",
	"ATTACK": {
		"UP": {
			"SLIGHT": "up_attack_slight",
			"HEAVY": "up_attack_heavy"
		},
		"DOWN": {
			"SLIGHT": "down_attack_slight",
			"HEAVY": "down_attack_heavy"
		},
		"SIDE": {
			"SLIGHT": "side_attack_slight",
			"HEAVY": "side_attack_heavy"
		}
	}
}

# 攻击配置
const ATTACK_CONFIG = {
	"combo0": {
		"type": "SLIGHT",  # 第一击使用轻击
		"damage": 15,
		"hit_frame": 3,
		"combo_window": 0.8,
		"description": "快速的轻击"
	},
	"combo1": {
		"type": "SLIGHT",   # 第二击使用轻击
		"damage": 25,
		"hit_frame": 4,
		"combo_window": 0.7,
		"description": "有力的重击"
	},
	"combo2": {
		"type": "HEAVY",   # 最后一击使用重击
		"damage": 35,
		"hit_frame": 4,
		"combo_window": 0.5,
		"description": "致命的终结技"
	}
}

# 节点引用
@onready var animated_sprite_2d = $AnimatedSprite2D

# 状态变量
var current_state: KnightState = KnightState.IDLE
var facing_direction: FacingDirection = FacingDirection.RIGHT
var movement_direction: Vector2 = Vector2.ZERO
var last_attack_direction: FacingDirection = FacingDirection.RIGHT
var current_combo: int = 0  # 当前连击数（0-2）
var combo_timer: float = 0.0  # 连击计时器
var enemies_in_range: Array = []
var target_enemy: Node2D = null
var attack_cooldown_timer: float = 0.0
var can_attack: bool = true
var auto_attack: bool = true
var has_hit: bool = false
var wood_count = 0  # 木材数量
var nearest_tree = null  # 最近的树
var auto_attack_timer: float = 0.0  # 自动攻击计时器
var can_auto_attack: bool = true    # 自动攻击冷却状态
var auto_combo_enabled: bool = true # 是否启用自动连击

# 调试绘制变量
var debug_draw_duration: float = 0.5  # 调试绘制持续时间
var debug_draw_timer: float = 0.0     # 调试绘制计时器
var debug_attack_info = null          # 存储攻击信息用于绘制

func _ready() -> void:
	super._ready()
	add_to_group("soldiers")
	add_to_group("knights")  # 添加到骑士组

	# 设置骑士血量
	health = 500

	# 设置骑士的选择指示器参数
	selection_indicator_offset = Vector2(0, 30)  # 骑士指示器偏移
	selection_indicator_radius = 20  # 骑士专用指示器半径

	# 初始化动画
	animated_sprite_2d.play(ANIMATION_STATES.IDLE)
	# 连接动画信号
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	animated_sprite_2d.frame_changed.connect(_on_animation_frame_changed)

	# 设置检测区域
	var detection_area = $DetectionArea
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

	play_idle_animation()

func update_facing_direction(direction: Vector2) -> void:
	if direction.length() == 0:
		return

	# 确定主要移动方向
	var abs_x = abs(direction.x)
	var abs_y = abs(direction.y)

	if abs_y > abs_x * 1.5:  # 如果垂直分量明显大于水平分量
		facing_direction = FacingDirection.UP if direction.y < 0 else FacingDirection.DOWN
	elif abs_x > abs_y * 1.5:  # 如果水平分量明显大于垂直分量
		facing_direction = FacingDirection.RIGHT if direction.x > 0 else FacingDirection.LEFT
	# 如果两个分量相近，保持当前的水平朝向
	elif abs_x >= abs_y:
		facing_direction = FacingDirection.RIGHT if direction.x > 0 else FacingDirection.LEFT

	# 更新动画朝向
	if facing_direction == FacingDirection.LEFT:
		animated_sprite_2d.flip_h = true
	elif facing_direction == FacingDirection.RIGHT:
		animated_sprite_2d.flip_h = false

func _process(delta: float) -> void:

	# 处理攻击冷却
	if !can_attack:
		attack_cooldown_timer += delta
		if attack_cooldown_timer >= KNIGHT_CONFIG.attack_cooldown:
			can_attack = true
			attack_cooldown_timer = 0.0

	# 处理自动攻击冷却
	if !can_auto_attack:
		auto_attack_timer += delta
		if auto_attack_timer >= KNIGHT_CONFIG.auto_attack_cooldown:
			can_auto_attack = true
			auto_attack_timer = 0.0

			# 当自动攻击冷却结束时，如果仍在连击窗口状态且没有目标，重置为Idle状态
			if current_state == KnightState.COMBO_WINDOW and (!target_enemy or !is_instance_valid(target_enemy)):
				reset_combo()

	# 处理连击窗口计时
	if current_state == KnightState.COMBO_WINDOW:
		combo_timer += delta
		var combo_key = get_combo_key()
		if ATTACK_CONFIG.has(combo_key) and combo_timer >= ATTACK_CONFIG[combo_key]["combo_window"]:
			# 连击窗口超时，强制回到idle状态
			reset_combo()

	# 自动攻击逻辑
	# 只有在未被选中时才执行自动攻击
	if auto_attack and !is_selected and target_enemy and can_attack and can_auto_attack:
		var distance = global_position.distance_to(target_enemy.global_position)

		# 检查目标是否在攻击范围内
		if distance <= KNIGHT_CONFIG.attack_range:
			# 根据当前状态决定攻击行为
			match current_state:
				KnightState.IDLE:
					# 从idle状态开始新的攻击
					start_combo()
					can_auto_attack = false
					auto_attack_timer = 0.0

				KnightState.COMBO_WINDOW:
					# 在连击窗口中，有概率继续连击
					if auto_combo_enabled and randf() > 0.2:  # 80%的概率继续连击（提高概率）
						continue_combo()
						can_auto_attack = false
						auto_attack_timer = 0.0
					else:
						# 不继续连击，回到idle状态
						reset_combo()

				KnightState.ATTACKING:
					# 正在攻击中，不做任何操作，等待攻击完成
					pass

				_:
					# 其他状态，强制回到idle
					change_state(KnightState.IDLE)
		else:
			# 目标超出攻击范围，如果不在移动状态，回到idle
			if current_state == KnightState.COMBO_WINDOW:
				reset_combo()
			elif current_state != KnightState.MOVING and current_state != KnightState.ATTACKING:
				change_state(KnightState.IDLE)

func _input(event: InputEvent) -> void:
	# 只有被选中的单位才响应按键输入
	if !is_selected:
		return

	if event.is_action_pressed("chop"):
		get_viewport().set_input_as_handled()

		# 状态转换逻辑
		match current_state:
			KnightState.COMBO_WINDOW:
				if can_attack:
					continue_combo()
			KnightState.IDLE, KnightState.MOVING:
				if can_attack:
					start_combo()
			KnightState.ATTACKING:
				# 在攻击状态下不响应新的攻击输入
				pass

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 处理移动和目标追踪
	# 只有在未被选中时才自动追踪和攻击敌人
	if !is_selected and target_enemy and is_instance_valid(target_enemy) and current_state != KnightState.ATTACKING:
		var distance = global_position.distance_to(target_enemy.global_position)
		if distance > KNIGHT_CONFIG.attack_range:
			# 超出攻击范围，向目标移动
			movement_direction = (target_enemy.global_position - global_position).normalized()
			velocity = movement_direction * KNIGHT_CONFIG.move_speed
			update_facing_direction(movement_direction)
			move_and_slide()
			if current_state != KnightState.COMBO_WINDOW:
				change_state(KnightState.MOVING)
		else:
			# 在攻击范围内，停止移动
			velocity = Vector2.ZERO
			movement_direction = Vector2.ZERO
			# 更新朝向以面对敌人
			var to_enemy = (target_enemy.global_position - global_position).normalized()
			update_facing_direction(to_enemy)
			if current_state != KnightState.COMBO_WINDOW:
				change_state(KnightState.IDLE)

	# 调用父类处理基本移动（处理键盘输入的移动）
	# 只有在被选中时才响应键盘输入
	if is_selected:
		super._physics_process(delta)

	# 更新状态和动画
	if current_state != KnightState.ATTACKING and current_state != KnightState.COMBO_WINDOW:
		if velocity.length() > 0:
			change_state(KnightState.MOVING)
			movement_direction = velocity.normalized()
			update_facing_direction(movement_direction)
		else:
			change_state(KnightState.IDLE)

func start_combo() -> void:
	current_combo = 0  # 从第一段连击开始
	start_attack()

func continue_combo() -> void:
	current_combo += 1
	if current_combo > 2:  # 连击范围：0-2（共3段连击）
		current_combo = 0
	start_attack()

func reset_combo() -> void:
	current_combo = 0  # 重置为初始状态

	# 根据当前速度决定进入哪个状态
	if velocity.length() > 0:
		change_state(KnightState.MOVING)
	else:
		change_state(KnightState.IDLE)

func start_attack() -> void:
	if current_state == KnightState.ATTACKING:
		return

	change_state(KnightState.ATTACKING)

	# 如果有目标，确保面向目标
	if target_enemy and is_instance_valid(target_enemy):
		var to_enemy = (target_enemy.global_position - global_position).normalized()
		update_facing_direction(to_enemy)

	# 获取并播放对应方向的攻击动画
	var attack_animation = get_attack_animation(current_combo)

	# 根据攻击类型设置动画速度
	var combo_key = "combo" + str(current_combo)
	if ATTACK_CONFIG[combo_key]["type"] == "HEAVY":
		animated_sprite_2d.speed_scale = 0.8  # 重击动画速度稍慢
	else:
		animated_sprite_2d.speed_scale = 1.0  # 轻击保持正常速度

	animated_sprite_2d.play(attack_animation)

func _on_animation_frame_changed() -> void:
	if current_state == KnightState.ATTACKING and not has_hit:
		var current_frame = animated_sprite_2d.frame
		var combo_key = get_combo_key()
		if ATTACK_CONFIG.has(combo_key) and current_frame == ATTACK_CONFIG[get_combo_key()]["hit_frame"]:
			perform_attack()
			has_hit = true

func _on_animation_finished() -> void:
	# 检查是否是攻击动画
	var current_animation = animated_sprite_2d.animation
	var is_attack_animation = false

	# 检查是否是任何方向的攻击动画
	for direction in ["UP", "DOWN", "SIDE"]:
		for attack_type in ["SLIGHT", "HEAVY"]:
			if ANIMATION_STATES.ATTACK[direction][attack_type] == current_animation:
				is_attack_animation = true
				break

	if current_state == KnightState.ATTACKING and is_attack_animation:
		# 重置动画速度
		animated_sprite_2d.speed_scale = 1.0

		# 判断是否应该进入连击窗口还是直接回到idle
		var should_enter_combo_window = false

		# 如果是玩家选中的单位，允许进入连击窗口
		if is_selected:
			should_enter_combo_window = true
		# 如果是自动攻击，且有目标在范围内，也进入连击窗口（移除can_auto_attack限制）
		elif auto_attack and target_enemy and is_instance_valid(target_enemy):
			var distance = global_position.distance_to(target_enemy.global_position)
			if distance <= KNIGHT_CONFIG.attack_range:
				should_enter_combo_window = true

		if should_enter_combo_window:
			# 进入连击窗口
			change_state(KnightState.COMBO_WINDOW)
		else:
			# 直接回到idle状态
			reset_combo()

func play_idle_animation() -> void:
	if current_state != KnightState.ATTACKING:
		animated_sprite_2d.play(ANIMATION_STATES.IDLE)

func update_animation(direction: Vector2) -> void:
	if current_state == KnightState.ATTACKING:
		return

	update_facing_direction(direction)

	if direction.length() > 0:
		animated_sprite_2d.play(ANIMATION_STATES.RUN)
	else:
		play_idle_animation()

# 视野内自动索敌
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("goblin") or body.is_in_group("goblin_buildings"):
		enemies_in_range.append(body)
		update_target()

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("goblin") or body.is_in_group("goblin_buildings"):
		enemies_in_range.erase(body)
		if body == target_enemy:
			target_enemy = null
		update_target()

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

# 收集木材
func collect_wood() -> void:
	wood_count += 1
	print("骑士收集到木材！当前数量：", wood_count)

# 设置最近的树
func set_nearest_tree(tree) -> void:
	nearest_tree = tree

func get_combo_key() -> String:
	return "combo" + str(current_combo)

func get_attack_animation(combo_number: int) -> String:
	var combo_key = "combo" + str(combo_number)
	if not ATTACK_CONFIG.has(combo_key):
		push_error("无效的连击编号：" + str(combo_number))
		combo_key = "combo0"  # 回退到基础攻击

	var attack_type = ATTACK_CONFIG[combo_key]["type"]
	var base_animation = ""

	# 根据朝向和攻击类型选择动画
	match facing_direction:
		FacingDirection.UP:
			base_animation = ANIMATION_STATES.ATTACK.UP[attack_type]
		FacingDirection.DOWN:
			base_animation = ANIMATION_STATES.ATTACK.DOWN[attack_type]
		FacingDirection.RIGHT, FacingDirection.LEFT:
			base_animation = ANIMATION_STATES.ATTACK.SIDE[attack_type]

	return base_animation

func perform_attack() -> void:
	# 根据攻击类型调整攻击范围和角度
	var combo_key = "combo" + str(current_combo)
	var is_heavy = ATTACK_CONFIG[combo_key]["type"] == "HEAVY"
	var attack_angle = PI / 4 if not is_heavy else PI / 3  # 重击有更大的攻击角度
	var attack_range = KNIGHT_CONFIG.attack_range * (1.2 if is_heavy else 1.0)  # 重击有更大的攻击范围
	var knockback_force = 300 if is_heavy else 150  # 重击有更强的击退效果

	# 获取所有敌对生物目标
	var potential_targets = get_tree().get_nodes_in_group("goblin")
	# 添加哥布林建筑作为可能的目标
	potential_targets.append_array(get_tree().get_nodes_in_group("goblin_buildings"))
	# 添加草人作为可能的目标
	potential_targets.append_array(get_tree().get_nodes_in_group("strawmen"))

	# 首先找到攻击范围内最近的敌人作为主要目标
	var primary_target = null
	var closest_distance = INF

	for target in potential_targets:
		var distance = global_position.distance_to(target.global_position)
		if distance <= attack_range and distance < closest_distance:
			closest_distance = distance
			primary_target = target

	# 如果没有找到主要目标，则不进行攻击
	if primary_target == null:
		return

	# 计算到主要目标的方向作为攻击基准线
	var primary_direction = (primary_target.global_position - global_position).normalized()

	var hits = []

	# 检查所有目标是否在攻击范围和角度内
	for target in potential_targets:
		var to_target = target.global_position - global_position
		var distance = to_target.length()

		# 检查距离
		if distance > attack_range:
			continue

		# 检查角度 - 以到主要目标的方向为基准
		var target_angle = primary_direction.angle_to(to_target.normalized())

		if abs(target_angle) > attack_angle / 2:
			continue

		# 记录命中
		hits.append(target)

	# 对所有命中的目标造成伤害
	for hit_target in hits:
		var damage = ATTACK_CONFIG[combo_key]["damage"]
		var knockback_direction = (hit_target.global_position - global_position).normalized() * 5
		if hit_target.has_method("take_damage"):
			hit_target.take_damage(damage, knockback_direction * knockback_force, 0.7)


# 状态转换函数
func change_state(new_state: KnightState) -> void:
	if current_state == new_state:
		return  # 避免重复的状态转换

	var old_state = current_state
	current_state = new_state

	# 退出旧状态
	match old_state:
		KnightState.ATTACKING:
			has_hit = false
		KnightState.COMBO_WINDOW:
			combo_timer = 0.0

	# 进入新状态
	match new_state:
		KnightState.IDLE:
			play_idle_animation()
		KnightState.MOVING:
			animated_sprite_2d.play(ANIMATION_STATES.RUN)
		KnightState.ATTACKING:
			can_attack = false
			has_hit = false
		KnightState.COMBO_WINDOW:
			combo_timer = 0.0
			can_attack = true  # 确保可以继续连击
			# 设置一个短暂的计时器，确保不在连击窗口中停留太久
			var max_combo_window = 0.5  # 最大连击窗口时间
			combo_timer = ATTACK_CONFIG[get_combo_key()]["combo_window"] - max_combo_window
