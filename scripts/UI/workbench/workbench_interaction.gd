# file: workbench_interaction.gd
# author: ponywu
# date: 2025-03-23
# description: 交互对象类型枚举，具体交互功能实现在 interaction_manager.gd 中

extends Node

# 交互对象类型枚举
enum InteractionType {
	NONE,    # 无交互
	WORKER,  # 工人交互
	BUILDING, # 建筑交互
	TREE,    # 树木交互
	GOLD_MINE # 金矿交互
}
