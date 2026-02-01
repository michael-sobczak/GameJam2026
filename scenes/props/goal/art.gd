extends Area2D
class_name Art

signal goal_reached(art_global_position: Vector2)

var _triggered := false

func _on_body_entered(body: Node) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	set_deferred("monitoring", false)
	goal_reached.emit(global_position)
