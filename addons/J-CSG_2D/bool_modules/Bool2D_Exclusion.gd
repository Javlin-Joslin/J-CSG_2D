extends RefCounted
## Module used by the CSG_2D nodes to perform boolean exclusion operations on polygons. (A - B) + (B - A)
class_name Bool2D_Exclusion

## Applies the boolean exclusion operation on the provided polygons
static func apply_operation( toPolys : Array[Dictionary], boolPolys : Array[Dictionary]) -> Array[ Dictionary ]:
	var finalPolys : Array[ Dictionary ] = []

	finalPolys = Bool2D_Difference.apply_operation( toPolys, boolPolys )
	finalPolys += Bool2D_Difference.apply_operation( boolPolys, toPolys )

	return finalPolys