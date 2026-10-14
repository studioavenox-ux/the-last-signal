@tool
extends StaticBody3D
## Physical, raycastable interactable. Gameplay decisions live in game.gd.

var kind: String = ""
var key: String = ""
var caption: String = ""
var enabled: bool = true


func prompt() -> String:
	if not enabled:
		return ""
	return "INTERACT  •  " + caption
