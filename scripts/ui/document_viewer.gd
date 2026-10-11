class_name DocumentViewer
extends CanvasLayer
## Full-screen reader for notes and posters. Pauses the game while open.
## Close with the button, Interact (E / gamepad A) or Pause (Esc / Back).

signal closed(document_id: StringName)

const PAUSE_SOURCE := &"document"

var current_document: StringName = &""
var _opened_frame: int = -1

@onready var root: Control = $Root
@onready var title_label: Label = %DocTitle
@onready var body_label: Label = %DocBody
@onready var scroll: ScrollContainer = %Scroll
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	root.visible = false
	GameState.document_requested.connect(open)
	close_button.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if not root.visible or Engine.get_process_frames() == _opened_frame:
		return
	if (
		event.is_action_pressed(&"interact")
		or event.is_action_pressed(&"pause")
		or event.is_action_pressed(&"ui_cancel")
	):
		get_viewport().set_input_as_handled()
		close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_open():
		close()


func is_open() -> bool:
	return root.visible


func open(document_id: StringName) -> void:
	var doc := StoryText.get_document(document_id)
	current_document = document_id
	title_label.text = String(doc.get("title", ""))
	body_label.text = String(doc.get("body", ""))
	scroll.scroll_vertical = 0
	root.visible = true
	_opened_frame = Engine.get_process_frames()
	GameState.request_pause(PAUSE_SOURCE)
	close_button.grab_focus()


func close() -> void:
	if not root.visible:
		return
	root.visible = false
	GameState.release_pause(PAUSE_SOURCE)
	AudioManager.play(&"paper", -8.0, 1.2)
	closed.emit(current_document)
