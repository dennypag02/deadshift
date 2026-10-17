extends Node
## Global gameplay event contract for the mutation rebuild.
## Existing Stage 2 gameplay is not wired to these signals in Milestone 2.

signal hit_landed(payload: Dictionary)
signal zombie_killed(payload: Dictionary)
signal status_applied(payload: Dictionary)
signal hazard_triggered(payload: Dictionary)
signal combo_fired(payload: Dictionary)
signal wave_started(payload: Dictionary)
signal wave_ended(payload: Dictionary)
signal mutation_taken(payload: Dictionary)
