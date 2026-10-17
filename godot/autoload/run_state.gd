extends Node
## Canonical run state for the mutation rebuild.
## Milestone 2 does not replace the existing runtime's current state yet.

var wave_number := 0
var modifier_id := ""
var held_mutations: Dictionary = {}
var tag_counts: Dictionary = {}
var meter_value := 0
var meter_stage := "Human"

func _ready() -> void:
	reset_run()

func reset_run() -> void:
	wave_number = 0
	modifier_id = ""
	held_mutations.clear()
	tag_counts = {
		"acid": 0,
		"fire": 0,
		"shock": 0,
		"bone": 0,
		"swarm": 0,
	}
	meter_value = 0
	meter_stage = "Human"

func snapshot() -> Dictionary:
	return {
		"wave_number": wave_number,
		"modifier_id": modifier_id,
		"held_mutations": held_mutations.duplicate(true),
		"tag_counts": tag_counts.duplicate(true),
		"meter_value": meter_value,
		"meter_stage": meter_stage,
	}
