@tool
@icon("res://addons/J-CSG_2D/Icons/CSG_2D_Triangle.svg")
extends CSG_2D_Combiner
## CSG_2D node that generates a triangle shape.
class_name CSG_2D_Triangle

#region Triangle Settings
## The width of the triangle's base.
@export var baseSize : float = 40.0:
	set(inp):
		baseSize = max(inp, 0.0)
		_recalc_polygons()

## The height of the triangle from the base to the apex.
@export var height : float = 40.0:
	set(inp):
		height = max(inp, 0.0)
		_recalc_polygons()

## The horizontal offset of the triangle's apex relative to the base's center.
@export var offset : float:
	set(inp):
		offset = inp
		_recalc_polygons()

## Amount of the triangle filled in. If the fillin is less than 1.0 the triangle will have a hole in the middle.[br]
## (1.0 = full triangle, 0.0 = no fill)
@export_range(0.0, 1.0) var fillin : float = 1.0:
	set(inp):
		fillin = inp
		_recalc_polygons()

## Enum for what direction the triangle should be drawn from when using the draw percent feature.
enum DRAW_FROM_ENUM { TOP, BOTTOM }
## What direction the triangle should be drawn from when using the draw percent feature.
@export var drawFrom : DRAW_FROM_ENUM = DRAW_FROM_ENUM.BOTTOM:
	set(inp):
		drawFrom = inp
		_recalc_polygons()

#endregion

#region Generate Shape
func generate_shape() -> Dictionary:
	if baseSize == 0.0 or height == 0.0 or fillin == 0.0 or drawPercent == 0.0:
		return { 'body': PackedVector2Array(), 'holes': [] }

	var poly : PackedVector2Array = _generate_tri()


	if drawPercent < 1.0:
		var centroid := _get_centroid(poly)
		poly = _get_percentage_polyVerts( poly )
		poly.append(centroid)
		# push the triangle up so that the base is centered on the origin.
		for i in poly.size():
			poly[i].y -= height*0.5
		
		if fillin < 1.0:
			var holePoly : PackedVector2Array = _generate_tri()
			# Shrink the hole poly twards the centroid based on the fillin value, and push it up.
			holePoly = PackedVector2Array([
				centroid + (holePoly[0] - centroid) * (1.0 - fillin) - Vector2(0, height*0.5),
				centroid + (holePoly[1] - centroid) * (1.0 - fillin) - Vector2(0, height*0.5),
				centroid + (holePoly[2] - centroid) * (1.0 - fillin) - Vector2(0, height*0.5),
			])
			var clipped := Geometry2D.clip_polygons(poly, holePoly)
			return { 'body': clipped[0], 'holes': [] }

		return { 'body': poly, 'holes': [] }
	
	for i in poly.size():
		poly[i].y -= height*0.5
	var centroid := _get_centroid(poly)

	if fillin < 1.0:
		# Create a hole poly by shrinking the original triangle towards the centroid based on the fillin value, 
		# and push it up.
		var holePoly : PackedVector2Array = PackedVector2Array([
			centroid + (poly[0] - centroid) * (1.0 - fillin),
			centroid + (poly[1] - centroid) * (1.0 - fillin),
			centroid + (poly[2] - centroid) * (1.0 - fillin),
		])
		holePoly.reverse()
		return { 'body': poly, 'holes': [holePoly] }

	return { 'body': poly, 'holes': [] }

## Helper function that generates a triangle polygon based on the current baseSize, height, and offset values.
func _generate_tri() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(offset, -height * 0.5),
		Vector2(baseSize * 0.5, height * 0.5),
		Vector2(-baseSize * 0.5, height * 0.5),
	])

## Helper function that calculates the centroid of a triangle given its vertices.
func _get_centroid(triangle : PackedVector2Array) -> Vector2:
	return (triangle[0] + triangle[1] + triangle[2]) / 3.0

## Generates a triangle polygon that's only drawn up to a certain percentage based on the drawPercent variable. 
## The triangle is drawn starting from either the top or bottom based on the drawFrom variable.
func _get_percentage_polyVerts( triangle : PackedVector2Array ) -> PackedVector2Array:
	var polyVerts : PackedVector2Array = []
	var centroid := _get_centroid(triangle)
	var leanAngle : float = (centroid - triangle[0]).angle() - PI * 0.5

	var intersectVert
	if drawFrom == DRAW_FROM_ENUM.BOTTOM:
		var bottomRay :=  Vector2(0.0, height + baseSize + abs(baseSize * offset) ).rotated( leanAngle + (TAU * drawPercent) )

		# through a else if chain we check if the a the bottom ray cast from the centroid intersects with any of the
		# triangle's edges, and we use the first edge it intersects with to determine how to construct the percentage 
		# triangle.
		# Intersect bottom edge
		intersectVert = Geometry2D.segment_intersects_segment(
				centroid, centroid + bottomRay,
				triangle[2], triangle[1]
			)
		if intersectVert == null:
			# Intersect right edge
			intersectVert = Geometry2D.segment_intersects_segment(
				centroid, centroid + bottomRay,
				triangle[0], triangle[1]
			)
			if intersectVert == null:
				# Intersect left edge
				intersectVert = Geometry2D.segment_intersects_segment(
					centroid, centroid + bottomRay,
					triangle[0], triangle[2]
				)

				polyVerts.append(intersectVert)
				polyVerts.append(triangle[2])
				polyVerts.append( Vector2(0.0, height*0.5) )

			else:
				polyVerts.append(intersectVert)
				polyVerts.append( triangle[0] )
				polyVerts.append( triangle[2] )
				polyVerts.append( Vector2(0.0, height*0.5) )
		else:
			polyVerts.append(intersectVert)
			# because the draw starts from the center of the bottom edge, if the draw percent is less than or equal to 0.5 
			# we only append the intersect vert and the bottom center vert, but if it's greater than 0.5 we append the 
			# intersect vert and both the left and right verts to draw the almost the full triangle.
			if drawPercent <= 0.5:
				polyVerts.append( Vector2(0.0, height*0.5) )
			else:
				polyVerts.append( triangle[1] )
				polyVerts.append( triangle[0] )
				polyVerts.append( triangle[2] )
				polyVerts.append( Vector2(0.0, height*0.5) )
	
	else: # DRAW_FROM_ENUM.TOP
		# Same logic as above but with the ray cast upwards and the drawing starting from the top.
		var topRay := Vector2(0.0, height + baseSize + abs(baseSize * offset)).rotated(leanAngle + PI + (TAU * drawPercent))
		# Intersects the right edge
		intersectVert = Geometry2D.segment_intersects_segment(
				centroid, centroid + topRay,
				triangle[0], triangle[1]
			)
		if intersectVert == null:
			# Intersects the bottom edge
			intersectVert = Geometry2D.segment_intersects_segment(
				centroid, centroid + topRay,
				triangle[1], triangle[2]
			)
			if intersectVert == null:
				# Intersects the left edge
				intersectVert = Geometry2D.segment_intersects_segment(
					centroid, centroid + topRay,
					triangle[2], triangle[0]
				)

				polyVerts.append(triangle[0])
				polyVerts.append(triangle[1])
				polyVerts.append(triangle[2])
				polyVerts.append(intersectVert)
			else:
				polyVerts.append(triangle[0])
				polyVerts.append(triangle[1])
				polyVerts.append(intersectVert)
		else:
			polyVerts.append(triangle[0])
			polyVerts.append(intersectVert)

	return polyVerts


func calc_uvs(poly: PackedVector2Array, offsetUVs: bool = true) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	var safeBase := max(baseSize, 0.001)
	var safeHeight := max(height, 0.001)
	for point in poly:
		if offsetUVs:
			var uvPos := Vector2(point.x / safeBase + 0.5, -point.y / safeHeight)
			uvPos *= textureScale
			uvPos += textureOffset
			uvs.append(uvPos)
		else:
			uvs.append(Vector2(point.x / safeBase + 0.5, -point.y / safeHeight))
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

## Enum used to keep track of the gizmo indices in the gizmos array.
enum GIZMO_INDEX_ENUM { TOP, BASESIZE, FILLIN, DRAW_PERCENT }
## Array containing this node's gizmos that are used by the J-Gizmos plugin to allow for in-editor manipulation of this node's properties.
var gizmos : Array = []

## Sets up the Gizmos for this node.
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

	var apexGizmo = HandleGizmo.new()
	apexGizmo.offset = apexGizmo.gizmoSize
	apexGizmo.gizmoOffsetVector = Vector2(0, -1)
	apexGizmo.quick_setup(_on_top_drag, "_undo_top", "_redo_top", "Move Top")

	var baseSizeGizmo = HandleGizmo.new()
	baseSizeGizmo.offset = baseSizeGizmo.gizmoSize
	baseSizeGizmo.gizmoOffsetVector = Vector2(1, 0)
	baseSizeGizmo.quick_setup(_on_basesize_drag, "_undo_basesize", "_redo_basesize", "Change Base Width")

	var fillinGizmo = HandleGizmo.new()
	fillinGizmo.handleVisual = HandleGizmo.HANDLE_VISUAL.SQUARE
	fillinGizmo.offset = fillinGizmo.gizmoSize
	fillinGizmo.quick_setup(_on_fillin_drag, "_undo_fillin", "_redo_fillin", "Change Fill")

	var drawPercentGizmo = HandleGizmo.new()
	drawPercentGizmo.offset = drawPercentGizmo.gizmoSize * 3.0
	drawPercentGizmo.quick_setup(_on_draw_percent_drag, "_undo_draw_percent", "_redo_draw_percent", "Change Draw Percent")

	gizmos = [apexGizmo, baseSizeGizmo, fillinGizmo, drawPercentGizmo]
	_position_gizmos()

## Since using some of the gizmos can change the position of other gizmos we just use one function to update the position of all gizmos
## at once based on the current properties of the node
func _position_gizmos() -> void:
	if gizmos.size() == 0:
		return
	var centroid := _get_centroid(_generate_tri())
	gizmos[GIZMO_INDEX_ENUM.TOP].position.y = -height
	gizmos[GIZMO_INDEX_ENUM.BASESIZE].position = Vector2(baseSize / 2.0, 0.0)

	# We want to align the fillin and draw percent gizmos with the end of the drawn triangle but, because the triangle polygon geometry is
	# is modified by a clip operation when draw percent is below 1.0 we cant rely on the actual polygon.body verts to position the gizmos,
	# so instead we generate a separate set of verts based on the draw percent to position the gizmos.
	var drawPolyVerts := _get_percentage_polyVerts( _generate_tri() )

	var fillinGizmo = gizmos[GIZMO_INDEX_ENUM.FILLIN]
	fillinGizmo.position = drawPolyVerts[0] - (drawPolyVerts[0] - centroid ) * (fillin)
	fillinGizmo.position.y -= height * 0.5
	fillinGizmo.gizmoOffsetVector = (drawPolyVerts[0] - centroid).normalized()
	
	var drawPos : Vector2
	if drawFrom == DRAW_FROM_ENUM.BOTTOM:
		drawPos = drawPolyVerts[0]
	else:
		drawPos = drawPolyVerts[-1]
	
	var drawPercentGizmo = gizmos[GIZMO_INDEX_ENUM.DRAW_PERCENT]
	drawPercentGizmo.position = drawPos - Vector2(0, height*0.5)
	drawPercentGizmo.gizmoOffsetVector = (drawPos - centroid).normalized()


#region Top Gizmo
## Called when the top gizmo is dragged to update the height variable based on the gizmos new position, and then recalculates the polygons.
func _on_top_drag(newPos: Vector2, _dragVector: Vector2, _gizmo) -> void:
	height = max(-newPos.y, 0.0)
	_recalc_polygons()
## Called when the top gizmo drag is undone to reset the height variable to its previous value.
func _undo_top(args: Dictionary) -> void:
	height = max(-args['oldPosition'].y, 0.0)
	_recalc_polygons()
## Called when the top gizmo drag is redone to set the height variable back to its new value.
func _redo_top(args: Dictionary) -> void:
	height = max(-args['newPosition'].y, 0.0)
	_recalc_polygons()
#endregion
#endregion


#region BaseSize Gizmo
## Called when the base size gizmo is dragged to update the baseSize variable based on the gizmos new position, and then recalculates the polygons.
func _on_basesize_drag(newPos: Vector2, _dragVector: Vector2, _gizmo) -> void:
	baseSize = max(newPos.x * 2.0, 0.0)
	_recalc_polygons()
## Called when the base size gizmo drag is undone to reset the baseSize variable to its previous value.
func _undo_basesize(args: Dictionary) -> void:
	baseSize = max(args['oldPosition'].x * 2.0, 0.0)
	_recalc_polygons()
## Called when the base size gizmo drag is redone to set the baseSize variable back to its new value.
func _redo_basesize(args: Dictionary) -> void:
	baseSize = max(args['newPosition'].x * 2.0, 0.0)
	_recalc_polygons()
#endregion


#region Fillin Gizmo


## Called when the fillin gizmo is dragged to update the fillin variable based on the gizmos new position, and then recalculates the polygons.
func _on_fillin_drag(newPos: Vector2, _dragVector: Vector2, _gizmo) -> void:
	fillin = _fillin_from_position(newPos)
	_recalc_polygons()
## Called when the fillin gizmo drag is undone to reset the fillin variable to its previous value.
func _undo_fillin(args: Dictionary) -> void:
	fillin = _fillin_from_position(args['oldPosition'])
	_recalc_polygons()
## Called when the fillin gizmo drag is redone to set the fillin variable back to its new value.
func _redo_fillin(args: Dictionary) -> void:
	fillin = _fillin_from_position(args['newPosition'])
	_recalc_polygons()
## Helper function that calculates the fillin value based on the given position.
func _fillin_from_position(pos: Vector2) -> float:
	var tri := _generate_tri()
	var centroid := _get_centroid(tri)
	var polyVerts := _get_percentage_polyVerts(tri)
	
	var anchor := polyVerts[0]
	pos.y += height * 0.5
	var dir := centroid - anchor
	var distSq := dir.length_squared()
	return clamp((pos - anchor).dot(dir) / distSq, 0.0, 1.0) if distSq > 0.0 else 1.0

#endregion


#region Draw Percent Gizmo
## Called when the draw percent gizmo is dragged to update the drawPercent variable based on the gizmos new position, and then recalculates the polygons.
func _on_draw_percent_drag(newPos: Vector2, _dragVector: Vector2, _gizmo) -> void:
	newPos.y += height * 0.5
	var newPercent : float = _drawPercent_from_position(newPos)

	var triangle := _generate_tri()
	var centroid := _get_centroid(triangle)
	var leanAngle : float = (centroid - triangle[0]).angle() - PI * 0.5

	if drawFrom == DRAW_FROM_ENUM.BOTTOM and newPos.y > 0.0:
		var cross := Vector2(0.0, 1.0).rotated(leanAngle).cross(newPos - centroid)
		if drawPercent > 0.5 and cross > 0.0:
			newPercent = 1.0
		elif drawPercent < 0.5 and cross < 0.0:
			newPercent = 0.0
	elif drawFrom == DRAW_FROM_ENUM.TOP and newPos.y < 0.0:
		var cross := Vector2(0.0, 1.0).rotated(leanAngle + PI).cross(newPos - centroid)
		if drawPercent > 0.5 and cross > 0.0:
			newPercent = 1.0
		elif drawPercent < 0.5 and cross < 0.0:
			newPercent = 0.0

	drawPercent = newPercent
	_recalc_polygons()
## Called when the draw percent gizmo drag is undone to reset the drawPercent variable to its previous value.
func _undo_draw_percent(args: Dictionary) -> void:
	drawPercent = _drawPercent_from_position(args['oldPosition'])
	_recalc_polygons()
## Called when the draw percent gizmo drag is redone to set the drawPercent variable back to its new value.
func _redo_draw_percent(args: Dictionary) -> void:
	drawPercent = _drawPercent_from_position(args['newPosition'])
	_recalc_polygons()
## Helper function that calculates the drawPercent value based on a given position.
func _drawPercent_from_position(pos: Vector2) -> float:
	var triangle := _generate_tri()
	var centroid := _get_centroid(triangle)
	var leanAngle : float = (centroid - triangle[0]).angle() - PI * 0.5

	var arcAngle : float
	if drawFrom == DRAW_FROM_ENUM.BOTTOM:
		arcAngle = fposmod((pos - centroid).angle() - (leanAngle + PI * 0.5), TAU)
	else: # TOP
		arcAngle = fposmod((pos - centroid).angle() - (leanAngle + PI * 0.5) - PI, TAU)
	return clamp(arcAngle / TAU, 0.0, 1.0)

#endregion

#endregion
