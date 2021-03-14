tool
extends EditorPlugin

var dock

func _enter_tree():
	var settings = get_editor_interface().get_editor_settings()
	dock = preload("res://addons/automatic_deploy/AutomaticDeployDock.tscn").instance()
	dock.settings = settings
	
	add_control_to_dock(DOCK_SLOT_LEFT_UR, dock)


func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()
