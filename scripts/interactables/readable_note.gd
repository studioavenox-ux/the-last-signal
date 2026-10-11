class_name ReadableNote
extends Node3D
## A note, notice or poster the player can read.
##
## The text lives in [StoryText].DOCUMENTS under [member document_id]; this node
## only handles presentation in the world. Reading opens the document viewer and
## sets the flag "read_<document_id>" (plus [member sets_flag] if given).

signal read(document_id: StringName)

@export var document_id: StringName = &"station_notice"
@export var prompt_text: String = "Read"
## Short title printed on the paper in the world (optional).
@export var heading_text: String = ""
## A few lines of preview text printed on posters (optional).
@export_multiline var preview_text: String = ""
## Show the clipboard / board behind the paper.
@export var show_backing: bool = true
@export var sets_flag: StringName = &""

@onready var interactable: Interactable = $Interactable
@onready var heading: Label3D = get_node_or_null(^"Heading")
@onready var preview: Label3D = get_node_or_null(^"Preview")
@onready var backing: Node3D = get_node_or_null(^"Backing")
@onready var paper: Node3D = get_node_or_null(^"Paper")


func _ready() -> void:
	interactable.prompt_text = prompt_text
	interactable.interacted.connect(_on_interacted)
	if heading != null:
		heading.text = heading_text
		heading.visible = not heading_text.is_empty()
	if preview != null:
		preview.text = preview_text
		preview.visible = not preview_text.is_empty()
	if backing != null:
		backing.visible = show_backing
		if not show_backing and paper != null:
			# Lie flat on the surface instead of floating above a missing board.
			var offset := paper.position.z - 0.002
			paper.position.z -= offset
			for label: Label3D in [heading, preview]:
				if label != null:
					label.position.z -= offset


func _on_interacted(_interactor: Node) -> void:
	AudioManager.play(&"paper", -3.0)
	GameState.set_flag(StringName("read_%s" % document_id))
	if sets_flag != &"":
		GameState.set_flag(sets_flag)
	GameState.open_document(document_id)
	read.emit(document_id)
