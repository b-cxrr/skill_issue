extends Label

const VERSION: String = "1.2.0"
const BUILD_NUMBER: int = 29
const DATE_CODE: String = "210926"

func _ready() -> void:
	text = "v%s • %d • %s" % [
		VERSION,
		BUILD_NUMBER,
		DATE_CODE
	]
