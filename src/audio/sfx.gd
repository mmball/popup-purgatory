class_name Sfx
extends RefCounted
## Sound playback through a small pool of AudioStreamPlayers under Main. Static
## so any node can `Sfx.play("click")`. Silent under --no-juice and when no pool
## was attached (unit tests). Assets are procedural OGGs from tools/make_audio.py.

static var enabled := true
static var sfx_volume_db := -6.0
static var music_volume_db := -14.0

static var _root: Node
static var _players: Array[AudioStreamPlayer] = []
static var _music: AudioStreamPlayer
static var _streams: Dictionary = {}
static var _current_music := ""
static var _next := 0
static var _rng := RandomNumberGenerator.new()  # cosmetic pitch variation only

const POOL := 8
const SFX_DIR := "res://assets/sfx/"
const MUSIC_DIR := "res://assets/music/"


static func attach(root: Node) -> void:
	_root = root
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		p.bus = "Master"
		root.add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	root.add_child(_music)


static func _stream(dir: String, name: String) -> AudioStream:
	var key := dir + name
	if not _streams.has(key):
		var path := "%s%s.ogg" % [dir, name]
		_streams[key] = load(path) if ResourceLoader.exists(path) else null
		if _streams[key] == null:
			push_warning("Sfx: missing audio asset " + path)
	return _streams[key]


## Plays a one-shot. `pitch` scales playback (1.0 = as recorded); a little random
## variation keeps repeated clicks from sounding mechanical.
static func play(name: String, pitch: float = 1.0, volume_db: float = 0.0, vary: float = 0.06) -> void:
	if not enabled or _players.is_empty():
		return
	var s := _stream(SFX_DIR, name)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.pitch_scale = pitch * (1.0 + (_rng.randf() * 2.0 - 1.0) * vary)
	p.volume_db = sfx_volume_db + volume_db
	p.play()


static func music(name: String, fade: float = 0.6) -> void:
	if _music == null:
		return
	if name == _current_music:
		return
	_current_music = name
	if not enabled:
		return
	var s := _stream(MUSIC_DIR, name)
	if s == null:
		_music.stop()
		return
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	_music.stream = s
	_music.volume_db = music_volume_db - 20.0
	_music.play()
	var tw := _music.create_tween()
	tw.tween_property(_music, "volume_db", music_volume_db, fade)


## Drops cached streams and player references (Main calls this on exit so the
## engine does not report resources still in use).
static func release() -> void:
	# Stop everything first: a player freed mid-playback leaves its playback
	# object registered with the audio server until exit (reported as a leak).
	for p: AudioStreamPlayer in _players:
		p.stop()
		p.stream = null
	if _music != null:
		_music.stop()
		_music.stream = null
	_streams.clear()
	_players.clear()
	_music = null
	_root = null
	_current_music = ""


static func stop_music() -> void:
	_current_music = ""
	if _music != null:
		_music.stop()
