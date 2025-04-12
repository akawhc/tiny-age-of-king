# @file: worker.gd
# @brief: 工人主脚本
# @author: ponywu
# @date: 2024-03-24

extends "res://scripts/units/selectable_unit.gd"

# 导入分离出的组件
@onready var animation_manager = $AnimationManager
@onready var wood_manager = $WoodManager
@onready var mining_manager = $MiningManager
@onready var chop_manager = $ChopManager

# 基础状态变量
var facing_direction = Vector2.RIGHT
var nearest_tree = null
var nearest_mine = null
var is_chopping = false
var is_mining = false

# 节点引用
@onready var animated_sprite_2d = $AnimatedSprite2D

func _ready() -> void:
	super._ready()  # 调用父类的 _ready
	add_to_group("workers")

	# 初始化组件
	_init_components()

	print("工人提示：空格键攻击(砍树/挖矿)，Q键丢弃木材")

func _init_components() -> void:
	# 初始化动画管理器
	animation_manager.init(animated_sprite_2d)

	# 初始化木材管理器
	wood_manager.init(self, $CarriedWood, $CarriedWood/Wood1, $CarriedWood/Wood2, $CarriedWood/Wood3)

	# 初始化挖矿管理器
	mining_manager.init(self, animated_sprite_2d)

	# 初始化砍树管理器
	chop_manager.init(self, animated_sprite_2d)

	# 连接必要的信号
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	animated_sprite_2d.frame_changed.connect(_on_animation_frame_changed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("chop"):
		# 如果已经在执行动画，不再开始新的动作
		if is_chopping or is_mining:
			return

		# 如果携带着木材，不能进行攻击动作
		if wood_manager.is_carrying:
			print("放下木材后才能进行攻击操作")
			return

		# 根据附近对象决定执行的动作
		if nearest_mine and not nearest_mine.is_depleted:
			# 如果附近有金矿，执行挖矿动作
			start_mine()
		else:
			# 否则执行砍树动作
			start_chop()
	elif event.is_action_pressed("drop") and wood_manager.is_carrying:
		wood_manager.drop_wood()

func _physics_process(delta: float) -> void:
	if is_moving:
		super._physics_process(delta)  # 调用父类的移动处理
	else:
		var direction = Vector2.ZERO

		# 如果正在砍树或挖矿，暂时不允许移动
		if not is_chopping and not is_mining:
			direction.x = Input.get_axis("ui_left", "ui_right")
			direction.y = Input.get_axis("ui_up", "ui_down")

		var old_velocity = velocity

		if direction:
			velocity = direction.normalized() * move_speed
			# 更新朝向
			if direction.x != 0:
				facing_direction = Vector2(sign(direction.x), 0)
				if not is_chopping and not is_mining:
					animated_sprite_2d.flip_h = direction.x < 0
		else:
			velocity = Vector2.ZERO

		# 更新动画
		if not is_chopping and not is_mining:
			animation_manager.set_animation_state(velocity, wood_manager.is_carrying)

		# 更新木材动画
		if wood_manager.is_carrying:
			wood_manager.update_animation(delta, old_velocity)

		move_and_slide()

# 重写父类的动画更新方法
func update_animation(direction: Vector2) -> void:
	if direction.x != 0:
		facing_direction = Vector2(sign(direction.x), 0)
		animated_sprite_2d.flip_h = direction.x < 0
	animation_manager.set_animation_state(velocity, wood_manager.is_carrying)

# 重写父类的待机动画方法
func play_idle_animation() -> void:
	animation_manager.set_animation_state(Vector2.ZERO, wood_manager.is_carrying)

func _on_animation_frame_changed() -> void:
	if is_chopping:
		chop_manager.check_frame_change(animated_sprite_2d)
	elif is_mining:
		mining_manager.check_frame_change(animated_sprite_2d, nearest_mine)

func _on_animation_finished() -> void:
	if is_chopping:
		is_chopping = false
		chop_manager.finish_animation()
		animation_manager.set_animation_state(velocity, wood_manager.is_carrying)
		print("砍树动作完成，可以再次按空格键执行新的动作")
	elif is_mining:
		is_mining = false
		mining_manager.finish_animation()
		animation_manager.set_animation_state(velocity, wood_manager.is_carrying)
		print("挖矿动作完成，可以再次按空格键执行新的动作")

func start_chop() -> void:
	if is_chopping or is_mining:
		print("已经在执行动作，无法开始砍树")
		return

	if wood_manager.is_carrying:
		print("正在携带木材，无法砍树")
		return

	is_chopping = true
	chop_manager.start_chop(facing_direction)
	print("工人开始砍树一次！")

func start_mine() -> void:
	if is_chopping or is_mining:
		print("已经在执行动作，无法开始挖矿")
		return

	if wood_manager.is_carrying:
		print("正在携带木材，无法挖矿")
		return

	if not nearest_mine:
		print("附近没有金矿")
		return

	if nearest_mine.is_depleted:
		print("金矿已被挖空！")
		return

	is_mining = true
	mining_manager.start_mine(facing_direction, nearest_mine)
	print("工人开始挖矿一次！使用锤子动作")

# 设置最近的树
func set_nearest_tree(tree) -> void:
	nearest_tree = tree

# 设置最近的金矿
func set_nearest_mine(mine) -> void:
	nearest_mine = mine

# 收集木材
func collect_wood(wood = null) -> void:
	# 如果已经在砍树或挖矿，不能收集木材
	if is_chopping or is_mining:
		return

	wood_manager.collect_wood(wood)

# 收集金币
func collect_gold(gold = null) -> void:
	if gold and gold.has_method("collected_by_worker"):
		gold.collected_by_worker()
		print("工人收集了1枚金币")

# 建造城堡
func build_castle() -> void:
	print("工人开始建造城堡")
	# 由 build_manager 管理具体的建造过程

# 建造房屋
func build_house() -> void:
	print("工人开始建造房屋")
	# 由 build_manager 管理具体的建造过程
