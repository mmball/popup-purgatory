class_name Telemetry
extends RefCounted
## Event log for one run. Pure: rows accumulate in memory; an optional JSONL
## sink streams them to disk. Schema is in docs/TELEMETRY.md; keep it in sync.
##
## Every row: {"seq": int, "t": seconds into the run, "wave": int, "ev": name, ...fields}

var rows: Array[Dictionary] = []
var seq := 0
var path := ""
var _sink: FileAccess


## Opens a JSONL sink. Returns false (and logs in memory only) if it cannot.
func open_sink(p_path: String) -> bool:
	var dir := p_path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	_sink = FileAccess.open(p_path, FileAccess.WRITE)
	if _sink == null:
		push_warning("Telemetry: cannot open %s" % p_path)
		return false
	path = p_path
	return true


func event(name: String, t: float, wave: int, fields: Dictionary = {}) -> void:
	var row := {"seq": seq, "t": snappedf(t, 0.01), "wave": wave, "ev": name}
	row.merge(fields)
	rows.append(row)
	seq += 1
	if _sink != null:
		_sink.store_line(JSON.stringify(row))


func flush() -> void:
	if _sink != null:
		_sink.flush()


func close() -> void:
	if _sink != null:
		_sink.close()
		_sink = null


func count(name: String) -> int:
	var n := 0
	for r: Dictionary in rows:
		if r["ev"] == name:
			n += 1
	return n


func of(name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in rows:
		if r["ev"] == name:
			out.append(r)
	return out
