@tool
extends EditorPlugin

var menuButton: MenuButton

func _enter_tree() -> void:
	menuButton = load("res://addons/J-CSG_2D/CSG_2D_Bake_UI.tscn").instantiate()
	menuButton.visible = false

	var menuPopup := menuButton.get_popup()
	var baseControl := EditorInterface.get_base_control()

	menuPopup.add_item("Bake Polygon Nodes", 0)
	menuPopup.set_item_icon( 0, baseControl.get_theme_icon("Polygon2D", "EditorIcons") )
	menuPopup.add_item("Bake Convex Collision", 1)
	menuPopup.set_item_icon( 1, baseControl.get_theme_icon("ConvexPolygonShape2D", "EditorIcons") )
	menuPopup.add_item("Bake Concave Collision (Simple)", 2)
	menuPopup.set_item_icon( 2, baseControl.get_theme_icon("ConcavePolygonShape2D", "EditorIcons") )
	menuPopup.add_item("Bake Concave Collision (Complex)", 3)
	menuPopup.set_item_icon( 3, baseControl.get_theme_icon("ConcavePolygonShape2D", "EditorIcons") )
	
	menuPopup.id_pressed.connect(_on_menu_item_pressed)

	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, menuButton)

	return

func _handles(object: Object) -> bool:
	return object is CSG_2D_Combiner

func _make_visible(visible: bool) -> void:
	if menuButton:
		menuButton.visible = visible

func _exit_tree() -> void:
	if menuButton:
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, menuButton)
		menuButton.queue_free()
		menuButton = null

func _on_menu_item_pressed(id: int) -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.is_empty():
		return
	var csgNode := selected[0] as CSG_2D_Combiner
	if csgNode == null:
		return
	var parent := csgNode.get_parent()
	if parent == null:
		return
	if csgNode.drawPolygons.is_empty():
		return
	
	var bakedNodes: Array = []
	var undoRedo : EditorUndoRedoManager = get_undo_redo()

	undoRedo.create_action("Bake CSG_2D")

	match id:
		0: # Bake Polygon Nodes
			var texture := csgNode.texture

			if texture != null:
				var textureSize := texture.get_size()
				
				for i in csgNode.drawPolygons.size():
					var polygon := csgNode.drawPolygons[i]
					var uvs := csgNode.calc_uvs(polygon, true)
					for uvi in uvs.size():
						uvs[uvi] *= textureSize

					var poly2D := Polygon2D.new()
					poly2D.name = "BakedPolygon_"+str(i)
					undoRedo.add_do_reference(poly2D)
					poly2D.polygon = polygon
					poly2D.uv = uvs
					poly2D.position = csgNode.position
					poly2D.texture = texture
					bakedNodes.append(poly2D)

			else:
				for i in csgNode.drawPolygons.size():
					var polygon := csgNode.drawPolygons[i]
					var poly2D := Polygon2D.new()

					poly2D.name = "BakedPolygon_"+str(i)
					undoRedo.add_do_reference(poly2D)
					poly2D.polygon = polygon
					poly2D.position = csgNode.position
					bakedNodes.append(poly2D)
		
		1: # Bake Convex Collision
			bakedNodes = [ _create_baked_collision(
				"BakedConvexCollision", 
				undoRedo, 
				csgNode, 
				CSG_2D_Combiner.COLLISION_TYPE_ENUM.CONVEX 
			) ]
		
		2: # Bake Concave Collision (Simple)
			bakedNodes = [ _create_baked_collision(
				"BakedConcaveCollision_Simple", 
				undoRedo, 
				csgNode, 
				CSG_2D_Combiner.COLLISION_TYPE_ENUM.CONCAVE_SIMPLE 
			) ]

		3: # Bake Concave Collision (Complex)
			bakedNodes = [ _create_baked_collision(
				"BakedConcaveCollision_Complex", 
				undoRedo, 
				csgNode, 
				CSG_2D_Combiner.COLLISION_TYPE_ENUM.CONCAVE_COMPLEX 
			) ]
	
	undoRedo.add_do_method(self, "_redo_bake_nodes", parent, bakedNodes )
	undoRedo.add_undo_method(self, "_undo_bake_nodes", csgNode, parent, bakedNodes)
	undoRedo.commit_action()

func _create_baked_collision(name: String, undoRedo : EditorUndoRedoManager, csgNode : Node, collisionType : int ) -> StaticBody2D:
	var staticBody := StaticBody2D.new()
	staticBody.name = 'BakedStaticBody'
	staticBody.position = csgNode.position

	undoRedo.add_do_reference( staticBody )
	var collisionShapes : Array[ Node2D ] = csgNode.generate_collision( collisionType )
	for i in collisionShapes.size():
		var collisionShape : Node2D = collisionShapes[i]
		collisionShape.name = name+"_"+str(i)
		staticBody.add_child(collisionShape)
	
	return staticBody

func _redo_bake_nodes(parent: Node, nodes: Array) -> void:
	EditorInterface.get_selection().clear()
	var sceneRoot := EditorInterface.get_edited_scene_root()
	for node in nodes:
		parent.add_child(node)
		node.owner = sceneRoot
		for child in node.get_children():
			child.owner = sceneRoot
		EditorInterface.get_selection().add_node(node)

func _undo_bake_nodes(csgNode: Node, parent: Node, nodes: Array) -> void:
	for node in nodes:
		if node.get_parent() == parent:
			parent.remove_child(node)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(csgNode)


func _get_plugin_name() -> String:
	return "J-CSG_2D"
