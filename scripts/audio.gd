class_name Sfx
extends RefCounted
## Tiny procedural UI sounds. No audio files ship with the project yet, so the
## chips and chimes are synthesised into AudioStreamWAV buffers at first use
## and cached. Swap any builder for a loaded .wav later without touching callers.

const RATE := 22050

static var _cache: Dictionary = {}


static func _tone(freq: float, seconds: float, decay: float, kind: String) -> AudioStreamWAV:
	var key := "%s_%d_%d_%d" % [kind, int(freq), int(seconds * 1000.0), int(decay * 100.0)]
	if _cache.has(key):
		return _cache[key]
	var count := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(RATE)
		var env := exp(-decay * t)
		var v := 0.0
		if kind == "square":
			v = 1.0 if sin(TAU * freq * t) >= 0.0 else -1.0
		elif kind == "noise":
			v = randf_range(-1.0, 1.0)
		else:
			v = sin(TAU * freq * t)
		# a touch of second harmonic keeps the blip from sounding like a test tone
		v += sin(TAU * freq * 2.0 * t) * 0.25
		var s := int(clampf(v * env * 0.22, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	_cache[key] = stream
	return stream


## Soft click when dialogue text advances.
static func talk() -> AudioStreamWAV:
	return _tone(520.0, 0.05, 45.0, "sine")


## Confirmation for choices, gifts and cooking.
static func confirm() -> AudioStreamWAV:
	return _tone(760.0, 0.12, 18.0, "sine")


## Gather/pickup sparkle.
static func pickup() -> AudioStreamWAV:
	return _tone(980.0, 0.10, 26.0, "sine")


## Something went wrong (failed dish, blocked choice).
static func fail() -> AudioStreamWAV:
	return _tone(220.0, 0.16, 14.0, "square")
