class_name HumanoidRig
extends RefCounted

static func build(parent: Node2D, body_color: Color, skin_color: Color) -> Dictionary:
	var refs: Dictionary = {}
	var polygons: Array = []

	var torso := Polygon2D.new()
	torso.name = "Torso"
	torso.polygon = PackedVector2Array([
		Vector2(-8, -24), Vector2(8, -24), Vector2(11, 0),
		Vector2(8, 24), Vector2(-8, 24), Vector2(-11, 0)
	])
	torso.color = body_color
	parent.add_child(torso)
	refs["torso"] = torso
	polygons.append(torso)

	var head := Polygon2D.new()
	head.name = "Head"
	head.polygon = PackedVector2Array([
		Vector2(-6, -32), Vector2(6, -32), Vector2(8, -24), Vector2(-8, -24)
	])
	head.color = skin_color
	parent.add_child(head)
	refs["head"] = head
	polygons.append(head)

	for side in [-1, 1]:
		var tag := "l" if side < 0 else "r"

		var shoulder := Node2D.new()
		shoulder.name = ("L" if side < 0 else "R") + "Shoulder"
		shoulder.position = Vector2(side * 9, -20)
		parent.add_child(shoulder)

		var upper := Polygon2D.new()
		upper.name = "UpperArm"
		upper.polygon = PackedVector2Array([
			Vector2(-3, 0), Vector2(3, 0), Vector2(3, 16), Vector2(-3, 16)
		])
		upper.color = skin_color.darkened(0.1)
		shoulder.add_child(upper)
		polygons.append(upper)

		var elbow := Node2D.new()
		elbow.name = ("L" if side < 0 else "R") + "Elbow"
		elbow.position = Vector2(0, 16)
		shoulder.add_child(elbow)

		var forearm := Polygon2D.new()
		forearm.name = "Forearm"
		forearm.polygon = PackedVector2Array([
			Vector2(-2.5, 0), Vector2(2.5, 0), Vector2(2.5, 14), Vector2(-2.5, 14)
		])
		forearm.color = skin_color
		elbow.add_child(forearm)
		polygons.append(forearm)

		refs[tag + "_shoulder"] = shoulder
		refs[tag + "_elbow"] = elbow

	for side in [-1, 1]:
		var tag := "l" if side < 0 else "r"

		var hip := Node2D.new()
		hip.name = ("L" if side < 0 else "R") + "Hip"
		hip.position = Vector2(side * 6, 22)
		parent.add_child(hip)

		var thigh := Polygon2D.new()
		thigh.name = "Thigh"
		thigh.polygon = PackedVector2Array([
			Vector2(-4, 0), Vector2(4, 0), Vector2(4, 18), Vector2(-4, 18)
		])
		thigh.color = body_color.darkened(0.15)
		hip.add_child(thigh)
		polygons.append(thigh)

		var knee := Node2D.new()
		knee.name = ("L" if side < 0 else "R") + "Knee"
		knee.position = Vector2(0, 18)
		hip.add_child(knee)

		var shin := Polygon2D.new()
		shin.name = "Shin"
		shin.polygon = PackedVector2Array([
			Vector2(-3.5, 0), Vector2(3.5, 0), Vector2(3, 16), Vector2(-3, 16)
		])
		shin.color = body_color.darkened(0.3)
		knee.add_child(shin)
		polygons.append(shin)

		refs[tag + "_hip"] = hip
		refs[tag + "_knee"] = knee

	refs["polygons"] = polygons
	return refs
