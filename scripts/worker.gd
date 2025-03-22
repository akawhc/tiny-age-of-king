extends CharacterBody2D

# 移动相关常量
const MOVE_SPEED = 120
const ATTACK_RANGE = 60

# 砍树相关常量
const CHOP_CONFIG = {
	"animation": "chop",
	"damage": 20,
	"hit_frame": 5,  # 在第5帧检测伤害
	"arc_angle": 60.0,  # 攻击弧度角度（度）
	"arc_distance": 70.0  # 攻击弧度距离
}

# 挖矿相关常量
const MINING_CONFIG = {
	"animation": "hammer",  # 挖矿使用锤子动作
	"damage": 20,
	"hit_frame": 5,  # 在第5帧检测伤害
	"efficiency": 1.0,  # 基础挖矿效率
	"arc_distance": 150.0,  # 攻击弧度距离
}

# 木材相关常量
const WOOD_CONFIG = {
	"drop_offset": Vector2(60, 60),  # 丢弃木材的偏移距离
	"collect_animation": {
		"duration": 0.5  # 收集动画持续时间
	},
	"max_carry": 3,  # 工人最多可以携带的木材数量
	"animation": {
		"bob_height": 2.0,       # 上下浮动高度
		"bob_speed": 3.0,        # 上下浮动速度
		"inertia_amount": 5.0,   # 惯性偏移量
		"inertia_smoothing": 5.0 # 惯性平滑系数
	}
}

# 动画状态
const ANIMATION_STATES = {
	"IDLE": "idle",
	"RUN": "run",
	"IDLE_LIFT": "lift",  # 携带物品时的待机动画
	"RUN_LIFT": "lift_run",  # 携带物品时的跑步动画
	"CHOP": "chop",  # 砍树动画
	"HAMMER": "hammer"  # 挖矿动画
}

# 节点引用
@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var carried_wood_sprite = $CarriedWood  # Node2D 节点
@onready var wood_sprite_1 = $CarriedWood/Wood1  # 第一个木材精灵
@onready var wood_sprite_2 = $CarriedWood/Wood2  # 第二个木材精灵
@onready var wood_sprite_3 = $CarriedWood/Wood3  # 第三个木材精灵

var wood_count = 0  # 木材数量
var gold_count = 0  # 金币数量
var nearest_tree = null  # 最近的树
var nearest_mine = null  # 最近的金矿
var is_chopping = false  # 是否正在砍树
var is_mining = false   # 是否正在挖矿
var mining_efficiency = MINING_CONFIG.efficiency  # 挖矿效率
var facing_direction = Vector2.RIGHT  # 角色朝向
var has_hit = false  # 是否已经造成伤害
var is_carrying = false  # 是否正在携带木材
var current_wood = null  # 当前正在收集的木材

# 木材动画相关变量
var animation_time = 0.0          # 动画计时器
var wood_offset = Vector2.ZERO    # 木材整体偏移量
var last_velocity = Vector2.ZERO  # 上一帧的速度，用于计算惯性

func _ready() -> void:
	add_to_group("players")  # 添加到玩家组，用于树木和木材的交互
	add_to_group("workers")  # 添加到工人组，用于金矿交互

	# 初始化动画和状态
	is_carrying = false
	is_chopping = false
	is_mining = false

	# 确保木材一开始是隐藏的
	if carried_wood_sprite:
		carried_wood_sprite.hide()

	# 设置初始动画状态
	animated_sprite_2d.play(ANIMATION_STATES.IDLE)

	# 连接信号
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	animated_sprite_2d.frame_changed.connect(_on_animation_frame_changed)

	print("工人提示：空格键攻击(砍树/挖矿)，Q键丢弃木材")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("chop"):
		# 如果已经在执行动画，不再开始新的动作
		if is_chopping or is_mining:
			return

		# 如果携带着木材，不能进行攻击动作
		if is_carrying:
			print("放下木材后才能进行攻击操作")
			return

		# 统一使用空格键攻击，根据附近对象决定执行的动作
		if nearest_mine and not nearest_mine.is_depleted:
			# 如果附近有金矿，执行挖矿动作
			start_mine()
		else:
			# 否则执行砍树动作
			start_chop()
	elif event.is_action_pressed("drop") and is_carrying:
		drop_wood()

func _physics_process(delta: float) -> void:
	if is_chopping or is_mining:  # 如果正在砍树或挖矿不处理移动
		return

	var direction = Vector2.ZERO
	direction.x = Input.get_axis("ui_left", "ui_right")
	direction.y = Input.get_axis("ui_up", "ui_down")

	var old_velocity = velocity

	if direction:
		velocity = direction.normalized() * MOVE_SPEED
		# 更新朝向
		if direction.x != 0:
			facing_direction = Vector2(sign(direction.x), 0)
			if not is_chopping and not is_mining:  # 与骑士一致，只在非攻击状态更新翻转
				animated_sprite_2d.flip_h = direction.x < 0
	else:
		velocity = Vector2.ZERO

	# 更新动画
	if not is_chopping and not is_mining:
		set_animation_state()

	# 更新木材动画
	if is_carrying:
		_update_wood_animation(delta, old_velocity)

	move_and_slide()

func _on_animation_frame_changed() -> void:
	if is_chopping and not has_hit and animated_sprite_2d.animation == CHOP_CONFIG.animation:
		var current_frame = animated_sprite_2d.frame
		if current_frame == CHOP_CONFIG.hit_frame:
			check_tree_hit()
			has_hit = true
	elif is_mining and not has_hit and animated_sprite_2d.animation == MINING_CONFIG.animation:
		var current_frame = animated_sprite_2d.frame
		if current_frame == MINING_CONFIG.hit_frame:
			check_mine_hit()
			has_hit = true


func _on_animation_finished() -> void:
	if is_chopping and animated_sprite_2d.animation == CHOP_CONFIG.animation:
		is_chopping = false
		has_hit = false
		set_animation_state()  # 砍树动画结束后，更新为正确的状态
		print("砍树动作完成，可以再次按空格键执行新的动作")
	elif is_mining and animated_sprite_2d.animation == MINING_CONFIG.animation:
		is_mining = false
		has_hit = false
		set_animation_state()  # 挖矿动画结束后，更新为正确的状态
		print("挖矿动作完成，可以再次按空格键执行新的动作")


func start_chop() -> void:
	if is_chopping or is_mining or is_carrying:  # 如果已经在砍树/挖矿或正在携带木材，不能砍树
		return

	is_chopping = true
	has_hit = false

	# 根据朝向设置动画翻转
	animated_sprite_2d.flip_h = facing_direction.x < 0

	# 播放砍树动画
	animated_sprite_2d.play(CHOP_CONFIG.animation)

func start_mine() -> void:
	if is_chopping or is_mining or is_carrying or not nearest_mine:  # 如果已经在砍树/挖矿或正在携带物品，不能挖矿
		return

	if nearest_mine.is_depleted:
		print("金矿已被挖空！")
		return

	is_mining = true
	has_hit = false

	# 根据朝向设置动画翻转
	animated_sprite_2d.flip_h = facing_direction.x < 0

	# 播放挖矿动画
	animated_sprite_2d.play(MINING_CONFIG.animation)
	print("工人开始挖矿！使用锤子动作")

func set_animation_state() -> void:
	# 如果正在砍树或挖矿，保持对应动画
	if is_chopping:
		return
	elif is_mining:
		return

	# 根据是否携带木材和移动状态设置动画
	if is_carrying:
		carried_wood_sprite.show()  # 确保木材节点可见

		# 根据wood_count显示对应数量的木材
		if wood_sprite_1:
			wood_sprite_1.visible = wood_count >= 1
		if wood_sprite_2:
			wood_sprite_2.visible = wood_count >= 2
		if wood_sprite_3:
			wood_sprite_3.visible = wood_count >= 3

		if velocity.length() > 0:
			animated_sprite_2d.play(ANIMATION_STATES.RUN_LIFT)
		else:
			animated_sprite_2d.play(ANIMATION_STATES.IDLE_LIFT)
	else:
		carried_wood_sprite.hide()  # 确保木材隐藏
		if velocity.length() > 0:
			animated_sprite_2d.play(ANIMATION_STATES.RUN)
		else:
			animated_sprite_2d.play(ANIMATION_STATES.IDLE)

func check_tree_hit() -> void:
	# 使用弧形区域检测来判断是否砍到树
	var space_state = get_world_2d().direct_space_state
	var attack_direction = Vector2.RIGHT if not animated_sprite_2d.flip_h else Vector2.LEFT

	# 计算攻击弧度的参数
	var arc_angle_rad = deg_to_rad(CHOP_CONFIG.arc_angle)  # 将角度转换为弧度
	var arc_distance = CHOP_CONFIG.arc_distance
	var hit_trees = []

	# 在弧形区域内进行多次射线检测，模拟弧形区域
	var num_rays = 5  # 使用5条射线来模拟弧形
	var base_angle = attack_direction.angle()  # 基础角度
	var start_angle = base_angle - arc_angle_rad / 2
	var angle_step = arc_angle_rad / (num_rays - 1)

	for i in range(num_rays):
		var current_angle = start_angle + i * angle_step
		var ray_direction = Vector2(cos(current_angle), sin(current_angle))

		var query = PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + ray_direction * arc_distance
		)
		query.collide_with_areas = true
		var result = space_state.intersect_ray(query)

		if result and "collider" in result:
			var collider = result.collider
			if collider.get_parent() is AnimatedSprite2D and collider.get_parent().is_in_group("trees"):
				# 避免重复添加同一棵树
				if not hit_trees.has(collider.get_parent()):
					hit_trees.append(collider.get_parent())

	# 对所有在弧形范围内的树造成伤害
	for tree in hit_trees:
		tree.take_damage(CHOP_CONFIG.damage)
		print("命中树木！")

	if hit_trees.is_empty():
		print("没有砍到树！")

# 检查挖矿攻击是否命中
func check_mine_hit() -> void:
	if not nearest_mine:
		print("无法挖矿：附近没有金矿")
		return

	if nearest_mine.is_depleted:
		print("无法挖矿：金矿已被挖空")
		return

	# 检查工人是否在金矿附近
	var distance_to_mine = global_position.distance_to(nearest_mine.global_position)
	print("与金矿的距离: ", distance_to_mine, " 攻击范围: ", MINING_CONFIG.arc_distance)

	if distance_to_mine <= MINING_CONFIG.arc_distance:
		# 对金矿造成伤害
		nearest_mine.take_damage(MINING_CONFIG.damage)
		print("工人挖掘金矿！造成 ", MINING_CONFIG.damage, " 点伤害")
	else:
		print("金矿太远了，无法挖掘！需要靠近些")

# 丢弃木材
func drop_wood() -> void:
	if not is_carrying or wood_count <= 0:
		return

	# 创建木材实例
	var wood_scene = preload("res://scenes/wood.tscn")
	var wood = wood_scene.instantiate()

	# 根据朝向设置木材位置
	var drop_direction = Vector2.RIGHT if not animated_sprite_2d.flip_h else Vector2.LEFT
	var random_offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
	wood.global_position = global_position + drop_direction * WOOD_CONFIG.drop_offset + random_offset

	# 将木材添加到场景中
	get_parent().add_child(wood)

	# 更新状态
	wood_count -= 1
	is_carrying = wood_count > 0
	set_animation_state()  # 这会处理木材的显示/隐藏
	print("工人丢弃木材！剩余数量：", wood_count, "/", WOOD_CONFIG.max_carry)

# 设置最近的树
func set_nearest_tree(tree) -> void:
	nearest_tree = tree

# 设置最近的金矿
func set_nearest_mine(mine) -> void:
	nearest_mine = mine
	if mine and not mine.is_depleted:
		print("工人进入金矿范围，按空格键挖矿")

# 收集木材
func collect_wood(wood = null) -> void:
	# 如果已经在砍树或挖矿，不能收集木材
	if is_chopping or is_mining:
		return

	# 如果已经达到最大携带数量，不能再收集
	if wood_count >= WOOD_CONFIG.max_carry:
		print("工人已经携带了最大数量的木材！")
		return

	# 如果传入了木材实例，说明是从场景中收集的
	if wood != null:
		current_wood = wood

		# 创建收集动画
		var tween = create_tween()
		tween.tween_property(
			current_wood,
			"global_position",
			global_position,
			WOOD_CONFIG.collect_animation.duration
		)

		# 等待动画完成后处理木材
		await tween.finished

		# 木材被收集后消失
		if current_wood:
			current_wood.collected_by_worker()
			current_wood = null

			# 增加木材数量
			wood_count += 1
			is_carrying = true

			# 更新动画状态
			set_animation_state()
			print("工人收集木材！剩余数量：", wood_count, "/", WOOD_CONFIG.max_carry)


# 更新木材动画
func _update_wood_animation(delta: float, old_velocity: Vector2) -> void:
	animation_time += delta

	# 计算惯性效果（速度变化的反方向）
	var velocity_change = velocity - old_velocity
	var target_offset = Vector2.ZERO

	if velocity_change.length() > 0.1:
		# 计算惯性方向（与速度变化相反）
		target_offset = -velocity_change.normalized() * WOOD_CONFIG.animation.inertia_amount

	# 平滑过渡到目标偏移
	wood_offset = wood_offset.lerp(target_offset, delta * WOOD_CONFIG.animation.inertia_smoothing)

	# 添加上下浮动效果（所有木材一起浮动）
	var bob_offset = sin(animation_time * WOOD_CONFIG.animation.bob_speed) * WOOD_CONFIG.animation.bob_height

	# 应用整体偏移到CarriedWood节点
	carried_wood_sprite.position = Vector2(0, bob_offset) + wood_offset

	# 确保木材可见性正确
	var wood_sprites = [wood_sprite_1, wood_sprite_2, wood_sprite_3]
	for i in range(wood_sprites.size()):
		if wood_sprites[i]:
			wood_sprites[i].visible = i < wood_count
