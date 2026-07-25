class_name DungeonItemData
extends Resource

enum ItemType { BOTTLE_EMPTY, LIQUID, POTION_FILLED }

@export var id: String
@export var name: String
@export var type: ItemType
@export var icon_color: Color = Color.WHITE
@export var combine_target: String
@export var combine_result: String
