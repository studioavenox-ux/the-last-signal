class_name Apparition
extends Node3D
## A dark silhouette that appears for a moment, then vanishes.
## Deliberately low-tech: two unshaded meshes toggled on and off.

signal vanished

var is_showing: bool = false


func _ready() -> void:
	visible = false


func appear(duration: float = 1.4) -> void:
	if is_showing:
		return
	is_showing = true
	visible = true
	await Sequence.wait(self, duration)
	vanish()


func vanish() -> void:
	if not is_showing:
		return
	is_showing = false
	visible = false
	vanished.emit()
