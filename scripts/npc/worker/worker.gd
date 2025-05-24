# @file: worker.gd
# @brief: 工人主脚本
# @author: ponywu
# @date: 2024-03-24

extends "res://scripts/units/selectable_unit.gd"

# 导入分离出的组件
@onready var animation_manager = $AnimationManager
@onready var wood_manager = $WoodManager
@onready var gold_manager = $GoldManager
@onready var meat_manager = $MeatManager
@onready var mining_manager = $MiningManager
@onready var chop_manager = $ChopManager
@onready var build_manager = $BuildManager

# 基础状态变量
var facing_direction = Vector2.RIGHT
var nearest_tree = null
var nearest_mine = null
var nearest_animal = null
var is_chopping = false
var is_mining = false
var is_building = false

# 节点引用
@onready var animated_sprite_2d = $AnimatedSprite2D

func _ready() -> void:
	super._ready()  # 调用父类的 _ready
	add_to_group("workers")
	add_to_group("soldiers")

	health = 50

	# 设置工人的选择指示器参数
	selection_indicator_offset = Vector2(0, 25)  # 工人的指示器偏移
	selection_indicator_radius = 20  # 工人专用指示器半径

	# 初始化组件
	_init_components()

	print("工人提示：空格键攻击(砍树/挖矿)，Q键丢弃木材")

func _init_components() -> void:
	# 初始化动画管理器
	animation_manager.init(animated_sprite_2d)

	# 初始化木材采集管理器
	wood_manager.init(self, $CarriedWood, $CarriedWood/Wood1, $CarriedWood/Wood2, $CarriedWood/Wood3)

	# 初始化金币采集管理器
	gold_manager.init(self, $CarriedGold, [$CarriedGold/Gold1])

	# 初始化肉类采集管理器
	meat_manager.init(self, $CarriedMeat, [$CarriedMeat/Meat1])

	# 初始化挖矿管理器
	mining_manager.init(self, animated_sprite_2d)

	# 初始化砍树管理器
	chop_manager.init(self, animated_sprite_2d)

	# 初始化建造管理器
	build_manager.init(self, animated_sprite_2d)

	# 连接必要的信号
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	animated_sprite_2d.frame_changed.connect(_on_animation_frame_changed)

func _input(event: InputEvent) -> void:
	# 只有被选中的单位才响应按键输入
	if !is_selected:
		return

	# 如果正在建造，跳过其他输入处理
	if is_building:
		return

	if event.is_action_pressed("chop"):
		# 阻止事件传递，确保UI按钮不会被触发
		get_viewport().set_input_as_handled()

		# 如果已经在执行动画，不再开始新的动作
		if is_chopping or is_mining:
			return

		# 如果携带着资源，不能进行攻击动作
		if is_carrying_any_resource():
			print("放下资源后才能进行攻击操作")
			return

		# 根据附近对象决定执行的动作
		if nearest_mine and not nearest_mine.is_depleted:
			# 如果附近有金矿，执行挖矿动作
			start_mine()
		else:
			# 否则执行砍树动作
			start_chop()
	elif event.is_action_pressed("drop"):
		drop_carried_resource()

func _physics_process(delta: float) -> void:
	# 如果正在砍树或挖矿，则不允许移动
	if is_chopping or is_mining:
		velocity = Vector2.ZERO
	# 如果正在建造且已经达到建造地点，则不允许移动
	elif is_building and build_manager.is_building and build_manager.worker.global_position.distance_to(build_manager.target_position) <= 5.0:
		velocity = Vector2.ZERO
	else:
		# 调用父类处理移动和键盘输入
		super._physics_process(delta)

		# 获取当前速度，用于更新资源动画
		var old_velocity = velocity

		# 如果有移动，更新朝向
		if velocity.length() > 0:
			if velocity.x != 0:
				facing_direction = Vector2(sign(velocity.x), 0)
				animated_sprite_2d.flip_h = velocity.x < 0

		# 更新资源动画
		if wood_manager.is_carrying:
			wood_manager.update_animation(delta, old_velocity)

		if has_node("GoldManager") and gold_manager.is_carrying:
			gold_manager.update_animation(delta, old_velocity)

		if has_node("MeatManager") and meat_manager.is_carrying:
			meat_manager.update_animation(delta, old_velocity)

	# 更新建造进度
	if is_building:
		build_manager.update_building(delta)

# 重写父类的动画更新方法
func update_animation(direction: Vector2) -> void:
	if direction.x != 0:
		facing_direction = Vector2(sign(direction.x), 0)
		animated_sprite_2d.flip_h = direction.x < 0

	# 使用动画管理器更新动画
	if not is_chopping and not is_mining and not is_building:
		animation_manager.set_animation_state(velocity, is_carrying_any_resource())

# 重写父类的待机动画方法
func play_idle_animation() -> void:
	if not is_chopping and not is_mining and not is_building:
		animation_manager.set_animation_state(Vector2.ZERO, is_carrying_any_resource())

func _on_animation_frame_changed() -> void:
	# 获取当前帧
	var current_frame = animated_sprite_2d.frame

	if is_chopping:
		# 处理砍树动画帧变化
		chop_manager.check_frame_change(animated_sprite_2d)
	elif is_mining:
		# 处理挖矿动画帧变化
		mining_manager.check_frame_change(animated_sprite_2d, nearest_mine)
	elif is_building:
		# 处理建造动画帧变化
		build_manager.on_build_animation_frame_changed(current_frame)

func _on_animation_finished() -> void:
	print("动画完成: ", animated_sprite_2d.animation)

	if is_chopping:
		is_chopping = false
		chop_manager.finish_animation()
		animation_manager.set_animation_state(velocity, is_carrying_any_resource())
		print("砍树动作完成，可以再次按空格键执行新的动作")
	elif is_mining:
		# 重置挖矿状态
		is_mining = false
		mining_manager.finish_animation()
		animation_manager.set_animation_state(velocity, is_carrying_any_resource())
		print("挖矿动作完成，可以再次按空格键执行新的动作")
	elif is_building:
		# 建造动画完成
		build_manager.on_build_animation_finished()
		print("建造动作完成，准备下一次建造")

func start_chop() -> void:
	if is_chopping or is_mining:
		print("已经在执行动作，无法开始砍树")
		return

	if is_carrying_any_resource():
		print("正在携带资源，无法砍树")
		return

	is_chopping = true
	chop_manager.start_chop(facing_direction)
	print("工人开始砍树一次！")

func start_mine() -> void:
	if is_chopping or is_mining:
		print("已经在执行动作，无法开始挖矿")
		return

	if is_carrying_any_resource():
		print("正在携带资源，无法挖矿")
		return

	if not nearest_mine:
		print("附近没有金矿")
		return

	if nearest_mine.is_depleted:
		print("金矿已被挖空！")
		return

	is_mining = true
	mining_manager.start_mine(facing_direction, nearest_mine)
	print("工人开始挖矿一次！")

# 设置最近的树
func set_nearest_tree(tree) -> void:
	nearest_tree = tree

# 设置最近的金矿
func set_nearest_mine(mine) -> void:
	nearest_mine = mine

# 设置最近的动物
func set_nearest_animal(animal) -> void:
	nearest_animal = animal

# 收集木材
func collect_wood(wood = null) -> void:
	# 如果已经在砍树或挖矿，不能收集木材
	if is_chopping or is_mining:
		return

	wood_manager.collect_wood(wood)

# 收集金币
func collect_gold(gold = null) -> void:
	if is_chopping or is_mining:
		return

	if has_node("GoldManager"):
		gold_manager.collect_gold(gold)
	elif gold and gold.has_method("collected_by_worker"):
		gold.collected_by_worker()
		print("工人收集了1枚金币，但没有金币管理器来存储它")

# 建造城堡
func build_castle(pos: Vector2) -> void:
	# 先确保工人不在其他状态
	is_chopping = false
	is_mining = false

	# 确保位置有效
	if pos == Vector2.ZERO:
		print("错误：无效的建造位置")
		return

	build_manager.build_castle(pos)

# 建造房屋
func build_house(pos: Vector2) -> void:
	# 先确保工人不在其他状态
	is_chopping = false
	is_mining = false

	# 确保位置有效
	if pos == Vector2.ZERO:
		print("错误：无效的建造位置")
		return

	build_manager.build_house(pos)

# 建造箭塔
func build_tower(pos: Vector2) -> void:
	# 先确保工人不在其他状态
	is_chopping = false
	is_mining = false

	# 确保位置有效
	if pos == Vector2.ZERO:
		print("错误：无效的建造位置")
		return

	build_manager.build_tower(pos)

# 修理建筑
func repair() -> void:
	print("工人开始修理建筑")
	build_manager.repair()

# 添加对各类资源的携带检查逻辑
func is_carrying_any_resource() -> bool:
	var carrying = false

	if wood_manager.is_carrying:
		carrying = true

	if has_node("GoldManager") and gold_manager.is_carrying:
		carrying = true

	if has_node("MeatManager") and meat_manager.is_carrying:
		carrying = true

	return carrying

# 添加统一的资源丢弃逻辑
func drop_carried_resource() -> void:
	if wood_manager.is_carrying:
		wood_manager.drop_wood()

	if has_node("GoldManager") and gold_manager.is_carrying:
		gold_manager.drop_gold()

	if has_node("MeatManager") and meat_manager.is_carrying:
		meat_manager.drop_meat()

# 添加肉类收集逻辑
func collect_meat(meat = null) -> void:
	if is_chopping or is_mining:
		return

	if has_node("MeatManager"):
		meat_manager.collect_meat(meat)
	elif meat and meat.has_method("collected_by_worker"):
		meat.collected_by_worker()
		print("工人收集了肉类，但没有肉类管理器来存储它")
