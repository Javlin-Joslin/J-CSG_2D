extends RefCounted
## Module used by the CSG_2D nodes to perform boolean difference operations on polygons. (A - B)
class_name Bool2D_Difference

## Applies the boolean difference operation on the provided polygons. 
static func apply_operation( toPolys : Array[Dictionary], boolPolys_ : Array[Dictionary]) -> Array[ Dictionary ]:
	var polys : Array[ Dictionary ] = toPolys.duplicate_deep()
	var boolPolys : Array[ Dictionary ] = boolPolys_.duplicate_deep()


	for bpi in boolPolys.size():
		polys = _clip_polys_against_bool( polys, boolPolys[bpi] )


	return( polys )

## Clips the provided polygons against the provided boolean polygon, returning the modified polygons.
static func _clip_polys_against_bool( toPolys : Array[ Dictionary ], boolPoly : Dictionary ) -> Array[ Dictionary ]:
	var modifiedPolys : Array[ Dictionary ] = []
	var polyIndex : int = 0

	# First we loop through the toPolys and check if they intersect with the boolPolys. If they do,
	# we add the boolPoly to the toPoly's list holes for later clipping and also take any parts of the
	# toPoly that overlap with any of the boolean polygon's holes and treat them as separate "island"
	# polygons.
	while polyIndex < toPolys.size():
		var poly : Dictionary = toPolys[polyIndex]
		var originalPolyHoles : Array = poly.holes.duplicate()

		var didIntersect : bool = false
		var intersectRes : Array = Geometry2D.intersect_polygons( poly.body, boolPoly.body )

		if intersectRes.size() > 0:
			didIntersect = true

			for hole in boolPoly.holes:
				var islandIntersection : Array = Geometry2D.intersect_polygons( poly.body, hole )
				for res in islandIntersection:
					modifiedPolys.append( {"body": res, "holes": originalPolyHoles.duplicate()} )

			poly.holes.append( boolPoly.body )
			poly.holes[-1].reverse()

		if didIntersect:
			toPolys.remove_at( polyIndex )
			modifiedPolys.append( poly )
		else:
			polyIndex += 1
	

	polyIndex = 0
	# Next we loop through the "modifiedPolys" and clip them against all if their holes testing how each
	# hole clips against the polygons body and taking the appropriate action based on the result.
	while polyIndex < modifiedPolys.size():
		var poly = modifiedPolys[polyIndex]

		var holeIndex := 0
		var polySurvived : bool = true
		while holeIndex < poly.holes.size():
			var hole : PackedVector2Array = poly.holes[holeIndex]
			var holeClipRes : Array = Geometry2D.intersect_polygons( poly.body, hole )

			# Hole doesn't touch polygon - remove it.
			if holeClipRes.size() == 0:
				poly.holes.remove_at( holeIndex )
			else:
				var clipResult : Array = Geometry2D.clip_polygons( poly.body, hole )
				# Hole completely clips polygon - Delete polygon and move to next one.
				if clipResult.size() == 0:
					modifiedPolys.remove_at( polyIndex )
					polySurvived = false
					break

				# Hole isn't actually a hole - apply clip to polygon, remove hole, and reset hole loop since polygon has changed.
				elif clipResult.size() == 1:
					poly.body = clipResult[0]
					poly.holes.remove_at( holeIndex )
					holeIndex = 0

				# Hole is actually a hole - move to next hole
				elif Geometry2D.is_polygon_clockwise( clipResult[1] ):
					holeIndex += 1

				# Hole cuts polygon into multiple pieces - remove hole, add all pieces as modifiedPolys, and move on.
				else:
					poly.holes.remove_at( holeIndex )
					for res in clipResult:
						modifiedPolys.append( {"body": res, "holes": poly.holes.duplicate()} )
					modifiedPolys.remove_at( polyIndex )
					polySurvived = false
					break
		
		if not polySurvived:
			continue
		
		holeIndex = 0
		# Loop through all surviving holes that touch each other.
		while holeIndex < poly.holes.size():
			var holeA : PackedVector2Array = poly.holes[holeIndex]
			
			var holeBIndex : int = holeIndex + 1
			while holeBIndex < poly.holes.size():
				var holeB : PackedVector2Array = poly.holes[holeBIndex]
				var mergeRes : Array = Geometry2D.merge_polygons( holeA, holeB )
				if mergeRes.size() == 1:
					mergeRes[0].reverse()
					holeA = mergeRes[0]
					poly.holes.remove_at( holeBIndex )
					holeBIndex = holeIndex + 1
				else:
					holeBIndex += 1
			
			poly.holes[holeIndex] = holeA
			holeIndex += 1
		
		modifiedPolys[polyIndex] = poly
		polyIndex += 1

	return( modifiedPolys + toPolys )