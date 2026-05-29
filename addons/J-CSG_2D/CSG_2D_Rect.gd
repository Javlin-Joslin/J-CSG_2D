@tool
@icon("res://addons/J-CSG_2D/Icons/CSG_2D_Rect.svg")
extends CSG_2D_Combiner
## CSG_2D node that generates a rectangle shape.
class_name CSG_2D_Rect

#region Rect Settings
## The size of the rectangle.
@export var size : Vector2 = Vector2(60.0, 60.0):
	set(inp):
		size = Vector2(max(inp.x, 0.0), max(inp.y, 0.0))
		_recalc_polygons()

## The amount of the rectangle filled in. If the fillin is less than 1.0 the rectangle will have a hole in the middle.[br]
## (1.0 = full rectangle, 0.0 = no fill)
@export_range(0.0, 1.0) var fillin : float = 1.0:
	set(inp):
		fillin = inp
		_recalc_polygons()
#endregion


#region Generate Shape
func generate_shape() -> Dictionary:
	if size.x == 0.0 or size.y == 0.0 or fillin == 0.0 or drawPercent == 0.0:
		return { 'body': PackedVector2Array(), 'holes': [] }

	var half := size * 0.5
	
	var poly := PackedVector2Array()
	if drawPercent < 1.0:
		poly = _get_percentage_polyVerts()
		poly.append(Vector2.ZERO)

		if fillin < 1.0:
			var holePoly := _generate_rect( half * (1.0 - fillin) )
			var clipped := Geometry2D.clip_polygons( poly, holePoly	)
			if clipped.size() > 0:
				return { 'body': clipped[0], 'holes': [] }

	else:
		poly = _generate_rect(half)

		if fillin < 1.0:
			var holePoly := _generate_rect( half * (1.0 - fillin) )
			holePoly.reverse()
			return { 'body': poly, 'holes': [holePoly] }

	return { 'body': poly, 'holes': [] }

## Helper function that generates a rectangular polygon based on the provided multiplier. Said multiplier is used
## to generate the hole polygon when fillin is less than 1.0.
func _generate_rect( multiplier : Vector2 ) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-1.0, 1.0) * multiplier,
		Vector2(-1.0, -1.0) * multiplier,
		Vector2(1.0, -1.0) * multiplier,
		Vector2(1.0, 1.0) * multiplier,
	])

## Generates a Rectange polygon that's only drawn up to a certain percentage based on the drawPercent variable. The 
## percentage is calculated in a clockwise direction starting from the top middle point of the rectangle.
func _get_percentage_polyVerts() -> PackedVector2Array:
	var percentRay := Vector2(0, size.y + size.x)
	percentRay = percentRay.rotated( (TAU * drawPercent) )
	
	# we go ahead and add the first point (top middle of the rectangle) that will always be drawn regardless of the 
	# drawPercent to the array.
	var polyVerts : Array[Vector2] = [Vector2(0.0, 1.0)]
	# then we add the other points in a clockwise direction based on the drawPercent.
	if drawPercent <= 0.125:
		polyVerts.append( Vector2(-1.0, 1.0) )
	elif drawPercent <= 0.375:
		polyVerts += [
			Vector2(-1.0, 1.0),
			Vector2(-1.0, -1.0),
		]
	elif drawPercent <= 0.625:
		polyVerts += [
			Vector2(-1.0, 1.0),
			Vector2(-1.0, -1.0),
			Vector2(1.0, -1.0),
		]
	elif drawPercent <= 0.875:
		polyVerts += [
			Vector2(-1.0, 1.0),
			Vector2(-1.0, -1.0),
			Vector2(1.0, -1.0),
			Vector2(1.0, 1.0),
		]
	else:
		polyVerts += [
			Vector2(-1.0, 1.0),
			Vector2(-1.0, -1.0),
			Vector2(1.0, -1.0),
			Vector2(1.0, 1.0),
			Vector2(0.0, 1.0),
		]
	
	# then we pop the last point of the array and replace it with the intersection point of the percentRay and the 
	# line between the last two points in the array to create a clean edge where the rectangle is cut off based on 
	# the drawPercent.
	polyVerts.append(Geometry2D.line_intersects_line(
		Vector2.ZERO, percentRay,
		polyVerts[-2], polyVerts[-2] - polyVerts.pop_back()
	))
	for i in range(polyVerts.size()):
		polyVerts[i] *= size * 0.5
	return polyVerts


func calc_uvs(poly: PackedVector2Array, offsetUVs: bool = true) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	var safeSize := Vector2(max(size.x, 0.001), max(size.y, 0.001))
	for point in poly:
		if offsetUVs:
			var uvPos := point / safeSize + Vector2(0.5, 0.5)
			uvPos *= textureScale
			uvPos += textureOffset
			uvs.append(uvPos)
		else:
			uvs.append(point / safeSize)
	return uvs

#endregion

#region Gizmos
func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		_setup_gizmos()

func _recalc_polygons() -> void:
	super._recalc_polygons()
	_position_gizmos()

## Enum used to keep track of the gizmo indexes in the gizmos array.
enum GIZMO_INDEX_ENUM { SIZE_X, SIZE_Y, FILLIN, DRAW_PERCENT }
## Array containing this node's gizmos that are used by the J-Gizmos plugin to allow for in-editor manipulation of this node's properties.
var gizmos : Array = []

## Sets up the gizmos for this node.
func _setup_gizmos() -> void:
	gizmos.clear()
	# We check if the Gizmo2D_Handle script exists before trying to set up the gizmos since the J-Gizmos plugin is an optional dependency 	
	# and we don't want to cause errors if it's not installed.
	if not FileAccess.file_exists("res://addons/J-Gizmos/Gizmos/Gizmo2D_Handle.gd"):
		return
	# Attempt to load the Gizmo2D_Handle script and if it fails we just don't set up the gizmos since they won't work without the script
	# as another layer of safety to prevent errors if the J-Gizmos plugin isn't installed.
	var HandleGizmo = load("res://addons/J-Gizmos/Gizmos/Gizmo2D_Handle.gd")
	if HandleGizmo == null:
		return

	var sizeXGizmo = HandleGizmo.new()
	sizeXGizmo.offset = sizeXGizmo.gizmoSize
	sizeXGizmo.gizmoOffsetVector = Vector2(1, 0)
	sizeXGizmo.quick_setup(_on_size_x_drag, "_undo_size_x", "_redo_size_x", "Change Width")

	var sizeYGizmo = HandleGizmo.new()
	sizeYGizmo.offset = sizeYGizmo.gizmoSize
	sizeYGizmo.gizmoOffsetVector = Vector2(0, 1)
	sizeYGizmo.quick_setup(_on_size_y_drag, "_undo_size_y", "_redo_size_y", "Change Height")

	var fillinGizmo = HandleGizmo.new()
	fillinGizmo.handleVisual = HandleGizmo.HANDLE_VISUAL.SQUARE
	fillinGizmo.gizmoOffsetVector = Vector2(0, -1)
	fillinGizmo.quick_setup(_on_fillin_drag, "_undo_fillin", "_redo_fillin", "Change Fill")

	var drawPercentGizmo = HandleGizmo.new()
	drawPercentGizmo.offset = drawPercentGizmo.gizmoSize * 3.0
	drawPercentGizmo.quick_setup(_on_draw_percent_drag, "_undo_draw_percent", "_redo_draw_percent", "Change Draw Percent")

	gizmos = [sizeXGizmo, sizeYGizmo, fillinGizmo, drawPercentGizmo]
	_position_gizmos()

## Since using some of the gizmos can change the position of other gizmos we just use one function to update the position of all gizmos
## at once based on the current properties of the node.
func _position_gizmos() -> void:
	if gizmos.size() == 0:
		return
	var half := size * 0.5
	gizmos[GIZMO_INDEX_ENUM.SIZE_X].position = Vector2(half.x, 0.0)
	gizmos[GIZMO_INDEX_ENUM.SIZE_Y].position = Vector2(0.0, half.y)
	gizmos[GIZMO_INDEX_ENUM.FILLIN].position = Vector2(0.0, half.y * -(1.0 - fillin))

	var dpPos := _get_percentage_polyVerts()[-1]
	var drawPercentGizmo = gizmos[GIZMO_INDEX_ENUM.DRAW_PERCENT]
	drawPercentGizmo.position = dpPos
	drawPercentGizmo.gizmoOffsetVector = dpPos.normalized() if dpPos.length() > 0.01 else Vector2(0, -1)


#region Size X Gizmo
## Called when the size X gizmo is dragged to update the size.x variable and recalculate the polygons.
func _on_size_x_drag(newPos: Vector2, _dragVector: Vector2, _gizmo) -> void:
	size = Vector2(max(newPos.x * 2.0, 0.0), size.y)
	_recalc_polygons()
## Called when the size X gizmo drag is undone to reset the size.x variable to its previous value.
func _undo_size_x(args: Dictionary) -> void:
	size = Vector2(max(args['oldPosition'].x * 2.0, 0.0), size.y)
	_recalc_polygons()
## Called when the size X gizmo drag is redone to set the size.x variable back to its new value.
func _redo_size_x(args: Dictionary) -> void:
	size = Vector2(max(args['newPosition'].x * 2.0, 0.0), size.y)
	_recalc_polygons()
#endregion


#region Size Y Gizmo
## Called when the size Y gizmo is dragged to update the size.y variable and recalculate the polygons.
func _on_size_y_drag(newPos: Vector2, _dragVector: Vector2, _gizmo) -> void:
	size = Vector2(size.x, max(newPos.y * 2.0, 0.0))
	_recalc_polygons()
## Called when the size Y gizmo drag is undone to reset the size.y variable to its previous value.
func _undo_size_y(args: Dictionary) -> void:
	size = Vector2(size.x, max(args['oldPosition'].y * 2.0, 0.0))
	_recalc_polygons()
## Called when the size Y gizmo drag is redone to set the size.y variable back to its new value.
func _redo_size_y(args: Dictionary) -> void:
	size = Vector2(size.x, max(args['newPosition'].y * 2.0, 0.0))
	_recalc_polygons()
#endregion


#region Fillin Gizmo
## Called when the fillin gizmo is dragged to update the fillin variable and recalculate the polygons.
func _on_fillin_drag(newPos: Vector2, _dragVector: Vector2, _gizmo) -> void:
	var halfY := size.y * 0.5
	if newPos.y < 0.0 and halfY > 0.0:
		fillin = 1.0 - min(-newPos.y / halfY, 1.0)
	else:
		fillin = 1.0
	_recalc_polygons()
## Called when the fillin gizmo drag is undone to reset the fillin variable to its previous value.
func _undo_fillin(args: Dictionary) -> void:
	var halfY := size.y * 0.5
	fillin = clamp( 1.0 - (-args['oldPosition'].y / halfY), 0.0, 1.0)
	_recalc_polygons()
## Called when the fillin gizmo drag is redone to set the fillin variable back to its new value.
func _redo_fillin(args: Dictionary) -> void:
	var halfY := size.y * 0.5
	fillin = clamp( 1.0 - (-args['newPosition'].y / halfY), 0.0, 1.0)
	_recalc_polygons()
#endregion


#region Draw Percent Gizmo
## Called when the draw percent gizmo is dragged to update the drawPercent variable and recalculate the polygons.
func _on_draw_percent_drag(newPos: Vector2, _dragVector: Vector2, _gizmo) -> void:
	newPos *= Vector2(1.0 / size.x, 1.0 / size.y) * 2.0
	var newPercent = _drawPercent_from_position(newPos)
	if newPos.y > 0.0:
		if drawPercent > 0.5 and newPos.x < 0.0:
			newPercent = 1.0
		elif drawPercent < 0.5 and newPos.x > 0.0:
			newPercent = 0.0
	drawPercent = newPercent
	_recalc_polygons()
## Called when the draw percent gizmo drag is undone to reset the drawPercent variable to its previous value.
func _undo_draw_percent(args: Dictionary) -> void:
	drawPercent = _drawPercent_from_position(args['oldPosition'] * Vector2(1.0 / size.x, 1.0 / size.y) * 2.0)
	_recalc_polygons()
## Called when the draw percent gizmo drag is redone to set the drawPercent variable back to its new value.
func _redo_draw_percent(args: Dictionary) -> void:
	drawPercent = _drawPercent_from_position(args['newPosition'] * Vector2(1.0 / size.x, 1.0 / size.y) * 2.0)
	_recalc_polygons()
## Helper function that calculates the drawPercent value based on a position..
func _drawPercent_from_position(pos: Vector2) -> float:
	var arcAngle : float = fmod(pos.angle() - (PI * 0.5) + TAU, TAU)
	return clamp(arcAngle / TAU, 0.0, 1.0)

#endregion

#endregion
