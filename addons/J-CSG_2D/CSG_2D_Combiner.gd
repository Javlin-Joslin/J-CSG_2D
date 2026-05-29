@tool
@icon("res://addons/J-CSG_2D/Icons/CSG_2D_Combiner.svg")
extends Node2D
## The base class for all CSG nodes. Contains all the logic for constructing the output drawn polygons and taking in and 
## applying CSG operations from child CSG nodes.[br]
## Please note that, just like 3D CSG shapes, this node and its inheritors are more CPU intensive than you would likely
## suspect and, as such, should be used sparingly, only for prototyping, or have their polygons baked into more static
## nodes.
class_name CSG_2D_Combiner

## An array of dictionaries containing all the polygons that result from this node's own shape and all the
## CSG operations its children apply to it. Used by parent shapes for hcsg operations[br]
## Dictionary format: [code]{ "body": PackedVector2Array, "holes": Array[ PackedVector2Array ] }[/code]
var polygons : Array[ Dictionary ] = []
## An array containing the drawable versions of the polygons in the polygons array. The polygon holes needing to be stitched
## into a polygon's body along with floating point precision issues necessitate this separate drawPolygons array.
var drawPolygons : Array[ PackedVector2Array ] = []
## The collision body this node uses when collisionType is not set to NONE.
var collisionBody : StaticBody2D = null

#region Generic Settings
## The draw style to use for this CSG shape.
enum DRAW_STYLE_ENUM { 
	SOLID, ## Draws the shape filled in with the solidColor and texture settings.
	WIREFRAME, ## Draws only the polygon wireframes.
	SOLID_AND_WIREFRAME, ## Draws both the solid fill and wireframe of the polygons.
	NONE ## The polygons will not be drawn, but will still affect CSG operations with other shapes.
}
## The draw style to use for this CSG shape.
@export var drawStyle : DRAW_STYLE_ENUM = DRAW_STYLE_ENUM.SOLID :
	set(inp):
		drawStyle = inp
		_recalc_polygons()

## The percentage of the shape to draw. Can be used to create simple reveal or dissolve effects.
@export_range(0.0, 1.0) var drawPercent : float = 1.0 :
	set(inp):
		drawPercent = clamp(inp, 0.0, 1.0)
		_recalc_polygons()

## The possible collision types for the shape.
enum COLLISION_TYPE_ENUM {
	NONE, ## No collision shape.
	CONVEX, ## Convex hull collision shape.
	CONCAVE_SIMPLE, ## Concave collision shape without holes carved in.
	CONCAVE_COMPLEX ## Concave collision shape with holes carved in.
}
## The collision type to use for this shape.
@export var collisionType : COLLISION_TYPE_ENUM = COLLISION_TYPE_ENUM.NONE

#endregion


#region Solid Settings
@export_group("Solid Draw Settings")
## The color to draw the solid fill of the polygons with.
@export var solidColor : Color = Color.WHITE :
	set(inp):
		solidColor = inp
		_recalc_polygons()

## The texture to draw the polygons with. The UVs are calculated based on the polygon's vertices, UVs 
## are calculated automatically by the base shape.
@export var texture : Texture2D = null :
	set(inp):
		texture = inp
		_recalc_polygons()

## Offset applied to the UVs or all this shape's polygons.
@export var textureOffset : Vector2 = Vector2.ZERO :
	set(inp):
		textureOffset = inp
		_recalc_polygons()

## Scale applied to the UVs of all this shape's polygons.
@export var textureScale : Vector2 = Vector2.ONE :
	set(inp):
		textureScale = inp
		_recalc_polygons()

#endregion

#region Wireframe Settings
@export_group("Wireframe Draw Settings")
## The color applied to the wireframes of this shape's polygons.
@export var wireframeColor : Color = Color.BLACK :
	set(inp):
		wireframeColor = inp
		queue_redraw()

## The width of the individual wires in the wireframes.
@export var width : int = -1 :
	set(inp):
		width = max(inp, -1)
		queue_redraw()

## If the wireframes will be drawn with antialiasing.
@export var antialiased : bool = false :
	set(inp):
		antialiased = inp
		queue_redraw()


#endregion

#region Outline Settings
@export_group("Outline Settings")
## Size of an outline drawn around the polygons of this shape.
@export var outlineSize : float = 0.0 :
	set(inp):
		outlineSize = max(inp, 0.0)
		_recalc_polygons()

## Color of the outline drawn around the polygons of this shape.
@export var outlineColor : Color = Color.BLACK :
	set(inp):
		outlineColor = inp
		_recalc_polygons()

## Determines how the corners of the outlines are drawn.
@export var outlineJoinStyle : Geometry2D.PolyJoinType = Geometry2D.PolyJoinType.JOIN_ROUND :
	set(inp):
		outlineJoinStyle = inp
		_recalc_polygons()

## Dictates whether the outlines of the polygons will be drawn with antialiasing.
@export var antialiasOutline : bool = false :
	set(inp):
		antialiasOutline = inp
		_recalc_polygons()

#endregion

#region Operation
@export_group('')
## The CSG operation this shape applies to its parent shape.
enum CSG_OPERATION_ENUM { 
	NONE, ## No operation.
	UNION, ## Union Operation: A + B
	DIFFERENCE, ## Difference Operation: A - B
	INTERSECTION, ## Intersection Operation: A * B
	EXCLUSION  ## Exclusion Operation: (A - B) + (B - A)
}
## The CSG operation this shape applies to its parent shape.
@export var operation : CSG_OPERATION_ENUM = CSG_OPERATION_ENUM.NONE :
	set(inp):
		operation = inp
		_recalc_polygons()

#endregion


#region Setup

func _ready():
	child_order_changed.connect(_recalc_polygons)
	_recalc_polygons()
	visibility_changed.connect(_on_visibility_changed)
	set_notify_local_transform( true )

## Called automatically when the visibility of this node changes in the scene tree and either clears the
## drawPolygons array or regenerates it and redraws the shape depending on whether the node is now visible or not.
func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		generate_draw_polygons()
		queue_redraw()
	else:
		drawPolygons.clear()

## Called automatically when the local transform of this node changes and notifies the parent CSG node, if it exists, 
## that this shape's polygons or position have changed and it needs to recalculate its own polygons.
func _notification( notif ):
	if notif == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		if operation == CSG_OPERATION_ENUM.NONE:
			return
		
		_notify_parent()

## Notifies the parent CSG node, if it exists, that this shape's polygons or position have changed and 
## it needs to recalculate its own polygons.
func _notify_parent():
	var parent = get_parent()
	if parent is CSG_2D_Combiner:
		parent._recalc_polygons()

#endregion

#region Calculate Polygons
## Recalculates the polygon dictionaries for this shape based on its own shape and the CSG operations of its children, 
## then calls the _notify_parent() function. Also regenerates the drawPolygons array and collision
## shapes if necessary.
func _recalc_polygons() -> void:
	polygons.clear()
	polygons.append( generate_shape() )

	if polygons[0].is_empty() or polygons[0].body.size() == 0:
		polygons.clear()
	
	for child in get_children():
		if child is CSG_2D_Combiner and child.operation != CSG_OPERATION_ENUM.NONE:
			polygons = child._apply_operation( polygons )
	
	_notify_parent()

	if is_visible_in_tree():
		generate_draw_polygons()
		queue_redraw()
	
	if not Engine.is_editor_hint() and collisionType != COLLISION_TYPE_ENUM.NONE:
		if collisionBody:
			collisionBody.queue_free()
		
		var collisionShapes := generate_collision( collisionType )
		var staticBody := StaticBody2D.new()
		add_child(staticBody)
		
		for shape in collisionShapes:
			staticBody.add_child(shape)

## Used by the CSG_2D_Combiner class inheritors to generate their base polygon.[br]
## Returned polygon dictionary format: [code]{ "body": PackedVector2Array, "holes": Array[ PackedVector2Array ] }[/code]
func generate_shape() -> Dictionary:
	return {}

## Used to calculated the UVs for the provided polygon. 
func calc_uvs(poly: PackedVector2Array, offsetUVs : bool = true) -> PackedVector2Array:
	if offsetUVs:
		var uvs : PackedVector2Array = PackedVector2Array()
		var lowestXY : Vector2 = poly[0]
		var greatestXY : Vector2 = poly[0]
		for point in poly:
			lowestXY.x = min(lowestXY.x, point.x)
			lowestXY.y = min(lowestXY.y, point.y)
			greatestXY.x = max(greatestXY.x, point.x)
			greatestXY.y = max(greatestXY.y, point.y)
		
		for point in poly:
			var uvPos : Vector2 = (point - lowestXY) / (greatestXY - lowestXY)
			uvPos *= textureScale
			uvPos += textureOffset
			uvs.append(uvPos)
		return uvs
	
	return poly

## Applies the CSG operation of this shape to the provided input polygon dictionaries and returns the result.
func _apply_operation( inputPolys : Array[ Dictionary ] ) -> Array[ Dictionary ]:
	var offsetPolygons : Array[ Dictionary ] = _offset_polygons()

	for poly in inputPolys:
		match operation:
			CSG_OPERATION_ENUM.UNION:
				return( Bool2D_Union.apply_operation( inputPolys.duplicate(), offsetPolygons ) )
		
			CSG_OPERATION_ENUM.DIFFERENCE:
				return( Bool2D_Difference.apply_operation( inputPolys.duplicate(), offsetPolygons ) )
			
			CSG_OPERATION_ENUM.INTERSECTION:
				return( Bool2D_Intersection.apply_operation( inputPolys.duplicate(), offsetPolygons ) )
			
			CSG_OPERATION_ENUM.EXCLUSION:
				return( Bool2D_Exclusion.apply_operation( inputPolys.duplicate(), offsetPolygons ) )
	
	return offsetPolygons

## Returns a copy of this shape's polygons with their body and hole verticies transformed by this node's 
## position, rotation, and scale. This is necessary so that the CSG operations of parent nodes are applied to the polygons in the correct positions.
func _offset_polygons() -> Array[ Dictionary ]:
	var offsetPolygons : Array[ Dictionary ] = []
	for poly in polygons:
		offsetPolygons.append( {"body": PackedVector2Array(), "holes": []} )
		for vect in poly.body:
			vect *= scale
			vect = vect.rotated(rotation)
			vect += position
			offsetPolygons[-1].body.append(vect)

		for hole in poly.holes:
			offsetPolygons[-1].holes.append( PackedVector2Array() )
			for vect in hole:
				vect *= scale
				vect = vect.rotated(rotation)
				vect += position
				offsetPolygons[-1].holes[-1].append(vect)

	return offsetPolygons


#region Generation Draw Polygons
## Generates the drawPolygons array from the polygons array by stitching the holes of each polygon into their 
## body.
func generate_draw_polygons() -> void:
	# var finalPolys : Array[ PackedVector2Array ] = []
	drawPolygons.clear()
	for poly in polygons:
		if poly.is_empty() or poly.body.size() == 0:
			continue
		
		if poly.holes.size() > 0:
			# Collect improtant data about the polygon holes and then order them from right to left in the datas array.
			var holeDatas : Array[ Dictionary ] = []
			for holeIndex in poly.holes.size():
				var hole = poly.holes[holeIndex]
				var holeRightmostIndex := 0
				var rightmostVert : Vector2 = hole[0]
				
				for holeVertIndex in hole.size():
					if hole[holeVertIndex].x > rightmostVert.x:
						rightmostVert = hole[holeVertIndex]
						holeRightmostIndex = holeVertIndex
				
				var holedata : Dictionary = {
					'holeIndex' : holeIndex,
					'rightmostIndex' : holeRightmostIndex,
					'rightmostVert' : rightmostVert,
				}
				if holeDatas.size() == 0:
					holeDatas.append( holedata )
				else:
					var dataInserted : bool = false
					for dataIndex in holeDatas.size():
						if holeDatas[dataIndex].rightmostVert.x < holedata.rightmostVert.x:
							holeDatas.insert(dataIndex, holedata)
							dataInserted = true
							break
					if not dataInserted:
						holeDatas.append( holedata )
			
			var body : PackedVector2Array = poly.body.duplicate()
		
			# Iterate though the sorted hole data and stitch each hole into the body
			for data in holeDatas:
				var bodyVertIndex := 0
				var bodyBridgeIndex := 0
				var bridgeVert = null
				
				# iterate through the body's segments and find the one that intersectects with  a ray cast from
				# the hole's rightmost vert to the right. Then, the intersection of that ray and the body's segment 
				# will be the bridge vert that is used to stitch the hole into the body.
				while bodyVertIndex < body.size():
					var nextIndex = (bodyVertIndex + 1) % body.size()

					var intersection = Geometry2D.segment_intersects_segment(
						data.rightmostVert, Vector2( max(body[bodyVertIndex].x, body[nextIndex].x) + 1.0, data.rightmostVert.y ),
						body[bodyVertIndex], body[nextIndex]
					)
					
					if intersection != null:
						# If there are multiple intersections, the bridge vert will be the one with the smallest x value.
						# (meaning the one closest to the hole's rightmost vert)
						if bridgeVert == null or intersection.x < bridgeVert.x:
							bridgeVert = intersection
							bodyBridgeIndex = bodyVertIndex

					bodyVertIndex += 1
				
				if bridgeVert != null:
					var stitchedPoly : PackedVector2Array
					var reorderedBody : PackedVector2Array = _reorder_verts( body, (bodyBridgeIndex + 1) % body.size() )
					reorderedBody.append( bridgeVert )
					
					var reorderedHole : PackedVector2Array = _reorder_verts( poly.holes[ data.holeIndex ], data.rightmostIndex )
					reorderedHole.append( reorderedHole[0] )
					reorderedHole.append( bridgeVert )

					body = reorderedHole + reorderedBody
			
			drawPolygons.append( body )
			
			
		else:
			drawPolygons.append(poly.body)
	


## Reorders the vertices of a loop so that the vertex at newFirstIndex becomes the first vertex in the 
## array so that the hole can be stitched into the polygon.
static func _reorder_verts( verts : PackedVector2Array, newFirstIndex : int ) -> PackedVector2Array:
	if newFirstIndex == 0:
		return verts.duplicate()
	var firstPart : PackedVector2Array = verts.slice(newFirstIndex, verts.size())
	var secondPart : PackedVector2Array = verts.slice( 0, newFirstIndex)
	return firstPart + secondPart

#endregion

#region Draw
func _draw():
	if drawStyle == DRAW_STYLE_ENUM.NONE:
		return
	
	if drawStyle == DRAW_STYLE_ENUM.WIREFRAME:
		_draw_wireframe( drawPolygons, wireframeColor, width, antialiased )
		return
	
	if outlineSize > 0.0:
		for poly in polygons:
			_draw_wireframe( 
				Geometry2D.offset_polygon( poly.body, outlineSize*0.5, outlineJoinStyle ),
				outlineColor, 
				outlineSize,
				antialiasOutline
			)
			
			for hole in poly.holes:
				_draw_wireframe( 
					Geometry2D.offset_polygon( hole, -outlineSize*0.5, outlineJoinStyle ),
					outlineColor, 
					outlineSize,
					antialiasOutline
				)

	for poly in drawPolygons:
		var uvs : PackedVector2Array = calc_uvs(poly)
		
		draw_polygon( poly, [solidColor], uvs, texture )
	
	if drawStyle == DRAW_STYLE_ENUM.SOLID_AND_WIREFRAME:
		_draw_wireframe( drawPolygons, wireframeColor, width, antialiased )
	
## Helper function to draw closed wireframes/polylines.
func _draw_wireframe( drawPolys : Array[PackedVector2Array], color : Color, lineWidth : float, antialiased : bool = true ) -> void:
	for poly in drawPolys:
		if poly.size() < 3:
			continue
		var closedPoly : PackedVector2Array = poly.duplicate()
		closedPoly.append(closedPoly[0])
		draw_polyline(
			closedPoly,
			color,
			lineWidth, 
			antialiased
		)

#endregion


#region Collision
## Generates an array of CollisionPolygon2D nodes based on the provided collision type and polygons array.
func generate_collision( mode : COLLISION_TYPE_ENUM ) -> Array[ Node2D ]:
	if mode == COLLISION_TYPE_ENUM.NONE:
		return []
	var collisionShapes : Array[ Node2D ] = []
	
	match mode:
		COLLISION_TYPE_ENUM.CONVEX:
			for poly in polygons:
				var convexShape := ConvexPolygonShape2D.new()
				convexShape.points = Geometry2D.convex_hull(poly.body)
				convexShape.points.remove_at( convexShape.points.size() - 1 ) # Remove the duplicate point added by convex_hull
				var collisionShape := CollisionShape2D.new()
				collisionShape.shape = convexShape
				collisionShapes.append( collisionShape )

		COLLISION_TYPE_ENUM.CONCAVE_SIMPLE:
			for poly in polygons:
				var concaveShape := ConcavePolygonShape2D.new()
				concaveShape.segments = _polygon_to_segments( poly.body )
				var collisionShape := CollisionShape2D.new()
				collisionShape.shape = concaveShape
				collisionShapes.append( collisionShape )
			
		COLLISION_TYPE_ENUM.CONCAVE_COMPLEX:
			if not is_visible_in_tree():
				generate_draw_polygons()
			
			for poly in drawPolygons:
				var collisionPolygon := CollisionPolygon2D.new()
				collisionPolygon.polygon = poly
				collisionShapes.append( collisionPolygon )

	return collisionShapes

## Helper function to convert a provided polygon PackedVector2Array into a PackedVector2Array of segments for use in ConcavePolygonShape2D.
func _polygon_to_segments( poly : PackedVector2Array ) -> PackedVector2Array:
	var segs : PackedVector2Array = PackedVector2Array()
	for i in poly.size()-1:
		segs.append(poly[i])
		segs.append(poly[ i + 1 ])
	
	segs.append(poly[ poly.size() - 1 ])
	segs.append(poly[0])

	return segs