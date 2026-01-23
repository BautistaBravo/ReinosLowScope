extends Node

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

# Library of generated streams
var sfx_library = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	music_player = AudioStreamPlayer.new()
	add_child(music_player)

	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)

	_generate_sfx()

func play_music(track_name):
	# In a real game, load stream from file.
	# Here we just log, or we could generate a drone.
	print("SoundManager: Playing Music '" + track_name + "'")
	# Stop previous
	music_player.stop()

func play_sfx(sfx_name):
	if sfx_library.has(sfx_name):
		sfx_player.stream = sfx_library[sfx_name]
		sfx_player.play()
	else:
		print("SoundManager: SFX '" + sfx_name + "' not found")

func _generate_sfx():
	sfx_library["click"] = _generate_beep(0.1, 800)
	sfx_library["hit"] = _generate_noise(0.2)
	sfx_library["buy"] = _generate_chime(0.4, 1200)
	sfx_library["victory"] = _generate_melody([600, 800, 1000])
	sfx_library["win_game"] = _generate_melody([500, 600, 700, 800, 1200])

# --- Procedural Generation Helpers ---

func _generate_beep(duration, freq):
	var sample_rate = 44100
	var frames = int(duration * sample_rate)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate

	var buffer = PackedByteArray()
	buffer.resize(frames * 2) # 16 bit = 2 bytes

	for i in range(frames):
		var t = float(i) / sample_rate
		var val = sin(t * freq * TAU)
		# Apply simple decay envelope
		val *= (1.0 - (float(i) / frames))

		var sample = int(val * 32767)
		buffer.encode_s16(i * 2, sample)

	stream.data = buffer
	return stream

func _generate_noise(duration):
	var sample_rate = 44100
	var frames = int(duration * sample_rate)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate

	var buffer = PackedByteArray()
	buffer.resize(frames * 2)

	for i in range(frames):
		var val = randf_range(-1.0, 1.0)
		val *= (1.0 - (float(i) / frames)) # Decay
		var sample = int(val * 32767)
		buffer.encode_s16(i * 2, sample)

	stream.data = buffer
	return stream

func _generate_chime(duration, freq):
	# Two tones
	var sample_rate = 44100
	var frames = int(duration * sample_rate)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate

	var buffer = PackedByteArray()
	buffer.resize(frames * 2)

	for i in range(frames):
		var t = float(i) / sample_rate
		var f = freq
		if i > frames / 2: f = freq * 1.5 # Second tone

		var val = sin(t * f * TAU)
		val *= 0.5

		var sample = int(val * 32767)
		buffer.encode_s16(i * 2, sample)

	stream.data = buffer
	return stream

func _generate_melody(notes_freqs):
	var note_duration = 0.2
	var sample_rate = 44100
	var total_frames = int(note_duration * notes_freqs.size() * sample_rate)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate

	var buffer = PackedByteArray()
	buffer.resize(total_frames * 2)

	var frame_idx = 0
	for freq in notes_freqs:
		var frames = int(note_duration * sample_rate)
		for i in range(frames):
			var t = float(i) / sample_rate
			var val = sin(t * freq * TAU)
			val *= (1.0 - (float(i) / frames))
			var sample = int(val * 32767)
			buffer.encode_s16(frame_idx * 2, sample)
			frame_idx += 1

	stream.data = buffer
	return stream
