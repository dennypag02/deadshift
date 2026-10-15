extends RefCounted
## Reusable transient records. No spawned projectile/effect/gem scene nodes.
var spare: Dictionary = {}
var allocations := 0
func warm(kind: String, count: int) -> void:
	if not spare.has(kind): spare[kind] = []
	for i in range(count):
		spare[kind].append({})
		allocations += 1
func push(items: Array, kind: String, values: Dictionary, cap: int) -> bool:
	if items.size() >= cap: return false
	if not spare.has(kind): spare[kind] = []
	var record: Dictionary
	if spare[kind].is_empty():
		record = {}
		allocations += 1
	else:
		record = spare[kind].pop_back()
	record.clear()
	record.merge(values)
	items.append(record)
	return true
func remove(items: Array, index: int, kind: String) -> void:
	var record: Dictionary = items[index]
	items.remove_at(index)
	if not spare.has(kind): spare[kind] = []
	spare[kind].append(record)
