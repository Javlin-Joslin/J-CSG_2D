extends RefCounted
## Module used by the CSG_2D nodes to perform boolean intersection operations on polygons. (A * B)
class_name Bool2D_Intersection

## Applies the boolean intersection operation on the provided polygons.
static func apply_operation( toPolys : Array[Dictionary], boolPolys : Array[Dictionary]) -> Array[ Dictionary ]:
	var diff : Array[ Dictionary ] = Bool2D_Difference.apply_operation( toPolys, boolPolys )
	return Bool2D_Difference.apply_operation( toPolys, diff )


