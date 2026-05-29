@tool
@icon("res://addons/J-CSG_2D/Icons/CSG_2D_Circle.svg")
extends CSG_2D_Combiner
## CSG_2D node that generates a circle shape.
class_name CSG_2D_Circle

#region Circle Settings
## The radius of the circle.
@export var radius : float = 30.0:
	set(inp):
		radius = inp
		_recalc_polygons()

## The amount that the circle is stretched in the y axis. [br](1.0 = no stretch)
@export var stretch : float = 1.0:
	set(inp):
		stretch = max(inp, 0.01)
		_recalc_polygons()

## Amount of the circle filled in. If the fillin is less than 1.0 the circle will have a hole in the middle.[br]
## (1.0 = full circle, 0.0 = no fill)
@export_range(0.0, 1.0) var fillin : float = 1.0 :
	set(inp):
		fillin = inp
		_recalc_polygons()

## The amount of points used to generate the circle. (2 = automatic)
@export var pointCount : int = 2:
	set(inp):
		pointCount = max(inp, 2)
		_recalc_polygons()

## The Base point count when below the baseline radius. (Used to calculate point count when pointCount is set to 2)
const BASELINE_POINT_COUNT : int = 18
## The baseline radius used to help automatically calculate the point count when pointCount is set to 2.
const BASELINE_RAD : float = 35.0

#region Generate Shape
func generate_shape() -> Dictionary:
	var totalPointCount : float = 0.0

	if fillin == 0.0 or radius == 0.0 or drawPercent == 0.0:
		return { 'body' : PackedVector2Array(), 'holes' : [] }

	if pointCount > 2:
		totalPointCount = pointCount
	else:
		# If the radius is above baseline we increase the point count based on how much above the baseline it is to 
		# help keep the circle looking smooth at larger sizes. 
		if radius >= BASELINE_RAD:
			totalPointCount = (radius / BASELINE_RAD) * BASELINE_POINT_COUNT
			totalPointCount = sqrt( (totalPointCount - BASELINE_POINT_COUNT)*12.0 )
		
		totalPointCount += BASELINE_POINT_COUNT
	

	var poly : PackedVector2Array
	if drawPercent < 1.0:
		poly = _generate_circle( totalPointCount, drawPercent )
	else:
		poly = _generate_circle( totalPointCount, drawPercent, true )
		

	var holePoly : PackedVector2Array = PackedVector2Array()
	if fillin < 1.0:
		holePoly = _generate_circle( totalPointCount, drawPercent, true )
		var offsetOp : Array[ PackedVector2Array ] = Geometry2D.offset_polygon(holePoly, -radius * ( fillin ))
		if offsetOp.size() > 0:
			holePoly = offsetOp[0]
		else:
			holePoly.clear()
	

	if drawPercent < 1.0:
		poly.append( Vector2.ZERO )
		poly = Geometry2D.clip_polygons( poly, holePoly )[0]

		return { 'body' : poly, 'holes' : [] }
	
	if holePoly.size() > 0:
		holePoly.reverse()
		return { 'body' : poly, 'holes' : [holePoly] }
	
	return { 'body' : poly, 'holes' : [] }

## Generates a circle polygon based on the provided point count and draw percent. If drawFull is false only the
## the percentage of the circle specified by drawPercent will be generated, otherwise the full circle will be generated 
## with drawPercent being used to determine how many extra points to add to the circle to ensure it is complete.
## (This is done so we can have a hole that matches the outer shell)
func _generate_circle( outterShellPointCount : int, outerShellDrawPercent : float, drawFull : bool = false) -> PackedVector2Array:
	var poly : PackedVector2Array = PackedVector2Array()
	var pointRadianArc : float = TAU * outerShellDrawPercent / outterShellPointCount

	if drawFull:
		var fullCount := ceili(outterShellPointCount / outerShellDrawPercent)
		for i in fullCount:
			poly.append( Vector2(0.0, radius).rotated(pointRadianArc * i) )
			poly[-1].y *= stretch
	else:
		for point in outterShellPointCount:
			poly.append( Vector2(0.0, radius).rotated(pointRadianArc*point) )
			poly[-1].y *= stretch
		
		poly.append( Vector2(0.0, radius).rotated(pointRadianArc*outterShellPointCount) )
		poly[-1].y *= stretch

	return poly

func calc_uvs(poly: PackedVector2Array, offsetUVs : bool = true) -> PackedVector2Array:
	var uvs : PackedVector2Array = PackedVector2Array()
	var uvExtents : Vector2 = Vector2(radius * 2.0, radius * stretch * 2.0)
	for point in poly:
		if offsetUVs:
			var uvPos : Vector2 = point / uvExtents + Vector2(0.5, 0.5)
			uvPos *= textureScale
			uvPos += textureOffset
			uvs.append(uvPos)
		else:
			uvs.append(point / uvExtents)
	
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
enum GIZMO_INDEX_ENUM { RADIUS, FILLIN, DRAW_PERCENT }
## Array containing this nodes gizmos that are used by the J-Gizmos plugin to allow for in-editor manipulation of this node's properties. (Radius, Fillin, and Draw Percent)
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

	var radiusGizmo = HandleGizmo.new()
	radiusGizmo.offset = radiusGizmo.gizmoSize
	radiusGizmo.gizmoOffsetVector = Vector2(1, 0)
	radiusGizmo.quick_setup(_on_radius_drag, "_undo_radius", "_redo_radius", "Change Radius")

	var fillinGizmo = HandleGizmo.new()
	fillinGizmo.handleVisual = HandleGizmo.HANDLE_VISUAL.SQUARE
	fillinGizmo.gizmoOffsetVector = Vector2(-1, 0)

	fillinGizmo.quick_setup(_on_fillin_drag, "_undo_fillin", "_redo_fillin", "Change Fill")

	var drawPercentGizmo = HandleGizmo.new()
	drawPercentGizmo.offset = drawPercentGizmo.gizmoSize * 3.0
	drawPercentGizmo.quick_setup(_on_draw_percent_drag, "_undo_draw_percent", "_redo_draw_percent", "Change Draw Percent")

	gizmos = [radiusGizmo, fillinGizmo, drawPercentGizmo]
	_position_gizmos()

## Since using some of the gizmos can change the position of other gizmos we just use one function to update the position of all gizmos
## at once based on the current properties of the node.
func _position_gizmos() -> void:
	if gizmos.size() == 0:
		return
	gizmos[GIZMO_INDEX_ENUM.RADIUS].position = Vector2(radius, 0)
	gizmos[GIZMO_INDEX_ENUM.FILLIN].position = Vector2(-radius * (1.0 - fillin), 0)

	var drawPercentGizmo = gizmos[GIZMO_INDEX_ENUM.DRAW_PERCENT]
	var dpPos : Vector2 = Vector2(0, radius).rotated(TAU * self.drawPercent)
	dpPos.y *= stretch
	drawPercentGizmo.position = dpPos
	drawPercentGizmo.gizmoOffsetVector = (dpPos - Vector2.ZERO).normalized()


#region Radius Gizmo
## Called when the radius gizmo is dragged to update the radius property based on the new position of the gizmo.
func _on_radius_drag(newPos : Vector2, _dragVector : Vector2, _gizmo) -> void:
	radius = max(newPos.x, 0.0)
	_recalc_polygons()
## Called when the radius gizmo drag is undone to reset the radius property to its previous value.
func _undo_radius(args : Dictionary) -> void:
	radius = args['oldPosition'].length()
	_recalc_polygons()
## Called when the radius gizmo drag is redone to set the radius property back to its new value.
func _redo_radius(args : Dictionary) -> void:
	radius = args['newPosition'].length()
	_recalc_polygons()
#endregion


#region Fillin Gizmo
## Called when the fillin gizmo is dragged to update the fillin property based on the new position of the gizmo.
func _on_fillin_drag(newPos : Vector2, _dragVector : Vector2, _gizmo) -> void:
	fillin = clamp(1.0 + newPos.x / radius, 0.0, 1.0)
	_recalc_polygons()
## Called when the fillin gizmo drag is undone to reset the fillin property to its previous value.
func _undo_fillin(args : Dictionary) -> void:
	fillin = clamp(1.0 + args['oldPosition'].x / radius, 0.0, 1.0) if radius > 0.0 else 1.0
	_recalc_polygons()
## Called when the fillin gizmo drag is redone to set the fillin property back to its new value.
func _redo_fillin(args : Dictionary) -> void:
	fillin = clamp(1.0 + args['newPosition'].x / radius, 0.0, 1.0) if radius > 0.0 else 1.0
	_recalc_polygons()
#endregion


#region Draw Percent Gizmo
## Called when the draw percent gizmo is dragged to update the drawPercent property based on the new position of the gizmo.
func _on_draw_percent_drag(newPos : Vector2, _dragVector : Vector2, _gizmo) -> void:
	if newPos.length() < 0.01:
		return

	var unstretchedPos : Vector2 = Vector2(newPos.x, newPos.y / stretch)
	var arcAngle : float = fmod(unstretchedPos.angle() - (PI * 0.5) + TAU, TAU)
	var newPercent : float = clamp(arcAngle / TAU, 0.0, 1.0)
	if drawPercent > 0.5 and newPos.x < 0.0 and newPos.y > 0.0:
		newPercent = 1.0
	elif drawPercent < 0.5 and newPos.x > 0.0 and newPos.y > 0.0:
		newPercent = 0.0
	drawPercent = newPercent
	_recalc_polygons()
## Called when the draw percent gizmo drag is undone to reset the drawPercent property to its previous value.
func _undo_draw_percent(args : Dictionary) -> void:
	var oldUnstretched : Vector2 = Vector2(args['oldPosition'].x, args['oldPosition'].y / stretch)
	var arcAngle : float = fmod(oldUnstretched.angle() - (PI * 0.5) + TAU, TAU)
	drawPercent = clamp(arcAngle / TAU, 0.0, 1.0)
	_recalc_polygons()
## Called when the draw percent gizmo drag is redone to set the drawPercent property back to its new value.
func _redo_draw_percent(args : Dictionary) -> void:
	var newUnstretched : Vector2 = Vector2(args['newPosition'].x, args['newPosition'].y / stretch)
	var arcAngle : float = fmod(newUnstretched.angle() - (PI * 0.5) + TAU, TAU)
	drawPercent = clamp(arcAngle / TAU, 0.0, 1.0)
	_recalc_polygons()
#endregion

#endregion