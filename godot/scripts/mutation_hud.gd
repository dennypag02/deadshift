extends Control

const TAGS := ["acid","fire","shock","bone","swarm"]
const COLORS := {
	"acid": Color("#9BD13B"),
	"fire": Color("#FF7A2C"),
	"shock": Color("#58C8FF"),
	"bone": Color("#E8DFC6"),
	"swarm": Color("#A46BD9")
}
var labels: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(8,160)
	size = Vector2(310,34)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",5)
	add_child(row)
	for tag in TAGS:
		var pill := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(COLORS[tag],0.18)
		style.border_color = COLORS[tag]
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		pill.add_theme_stylebox_override("panel",style)
		row.add_child(pill)
		var label := Label.new()
		label.text = "%s 0" % str(tag).substr(0,1).to_upper()
		label.add_theme_font_size_override("font_size",16)
		label.add_theme_color_override("font_color",COLORS[tag])
		pill.add_child(label)
		labels[tag] = label
	MutationManager.slots_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	for tag in TAGS:
		labels[tag].text = "%s %d" % [str(tag).substr(0,1).to_upper(),int(RunState.tag_counts.get(tag,0))]
