extends TextureRect

enum {INDEFINITE, PLAY_WITH_VOICE, PLAY_WITH_TEXT}

## SETUP ##
const PORTRAITS_FOLDER = 'res://img/characters/' # leave empty if you want to type entire path in the JSON
const PORTRAIT_IMAGE_FORMAT = 'png' # To enable animated portraits, the pathnames for a portrait must end in this extension,
						# if they are not animated, or end in 'tres' extension and be a SpriteFrames resource, if they are animated.
const DEFAULT_PORTRAIT_ANIM_MODE : int = PLAY_WITH_VOICE # For animated character portraits, this offers the ability to play
	# under certain conditions, as well as skip to the last frame and automatically end the animation under other conditions.
	# 0 / INDEFINITE - animation will start immediately when portrait appears.
	# 1 / PLAY_WITH_VOICE - animation will start when VoiceGenerator starts and end when VoiceGenerator is done.
	# 2 / PLAY_WITH_TEXT - animation will start when phoenetic text starts printing and end when text is finished printing.
	# Note that your animation will not loop if you have 'one shot' enabled regardless of this property.
	# This value can be changed for one text block by adding a "portrait_mode" parameter that holds a string (one of the above phrases)
const DEFAULT_SYNC_ANIM := true # will attempt to match portrait animation speed with speech speed and pauses for settings 1 and 2 above.
	# This value can be changed for one text block by adding a "sync_animation" parameter that holds 'true' or 'false.'
const FILTER := false # whether to apply filter to and create mipmaps for images when importing for portraits.
const MIPMAPS := false # this won't be necessary unless your dialogue box and/or portraits are scaled.
const SHOW_BOTH_SPRITES := false # If false, hides one sprite whenever the other one is shown (only one character is seen at a time)

var inactive_portrait := Color(0.75, 0.75, 0.75, 1.0)
var active_portrait := Color(1.0, 1.0, 1.0, 1.0)

var blink_freq_min : float = 1.0 # if you have an animation for "idle_portrait", it will play automatically \
var blink_freq_max : float = 3.0 # at random intervals, the range of which are defined here, in seconds.

var shake_weak = 1
var shake_regular = 2
var shake_strong = 4
var shake_short = 0.25
var shake_medium = 0.5
var shake_long = 2
var shake_base = 20

## END OF SETUP ##
const NON_PHOENETIC = [' ', '!', '?', '.', ',', '\n', '*', '~', '|', '-'] # characters that don't trigger a portrait's speaking animation.
const PAUSE_CHARAS  = ['!', '?', '.', ',', '\n', '*', '~', '|', '-'] # characters that pause a portrait's speaking animation. same as above but no space.
onready var parent = get_parent()
var active := false setget set_active
var portrait_mode : int = DEFAULT_PORTRAIT_ANIM_MODE
var sync_anim : bool = DEFAULT_SYNC_ANIM
var original_fps : int # original framerate of animated portrait, used to modify framerate if sync_anim is enabled.
var shake_amount
var shake_timer := -60.0 # this is the value whenever the timer is not running.
var blink_timer := -60.0 # this is the value whenever the timer is not running.
var idle_portrait_path := ""
var idle := false # true after the text/voice has finished and the texture switches to an idle_portrait (if given).
var imagetex : ImageTexture = ImageTexture.new()

func clean():
	portrait_mode = DEFAULT_PORTRAIT_ANIM_MODE
	sync_anim = DEFAULT_SYNC_ANIM
	idle_portrait_path = ""
	shake_timer = -60
	idle = false
	rect_position = Vector2.ZERO


func set_active(activate: bool):
	if activate: activate()
	else: deactivate()
	
func activate():
	active = true
	if SHOW_BOTH_SPRITES:
		modulate = active_portrait
	show()

func deactivate():
	active = false
	if SHOW_BOTH_SPRITES:
		modulate = inactive_portrait
		stop_portrait_anim()
	else: hide()


func set_portrait_mode(mode_name: String):
	match mode_name.to_lower():
		'play_with_voice':
			portrait_mode = PLAY_WITH_VOICE
		'play_with_text':
			portrait_mode = PLAY_WITH_TEXT
		'indefinite':
			portrait_mode = INDEFINITE
		var invalid:
			print("error: invalid portrait_mode ", invalid)

func load_portrait(file_name: String) -> bool:
	var path = PORTRAITS_FOLDER.plus_file(file_name)

	if file_name.get_extension().to_lower() == PORTRAIT_IMAGE_FORMAT.to_lower(): #non-animated portrait
		var img : Image = Image.new()
		var error = img.load(path)
		if error:
			print("Invalid file name ", file_name, " for portrait")
			return true

		var flags = int(MIPMAPS) + 4*int(FILTER) # see Texture documentation.
		imagetex = ImageTexture.new()
		imagetex.create_from_image(img, flags)
		texture = imagetex
		
	elif file_name.get_extension().to_lower() == 'tres': #animated portrait (SpriteFrames resource)
		var resource = load(path)
		if not resource is AnimatedTexture:
			print("Error: ", file_name, " is not an AnimatedTexture.")
			return true
		if resource == null:
			print("Resource ", file_name, " not found.")
			return true

		original_fps = resource.fps
		texture = resource
		
		if not idle and portrait_mode == INDEFINITE:
			play_portrait_anim()
		else:
			pause_portrait_anim()
	
	else:
		print("File extension missing or invalid for ", file_name)
		return true
	
	#force parent resize. this is necessary for some reason.
	show()
	get_parent().get_parent().rect_size.y = 0
	get_parent().get_parent().margin_bottom = 0
	get_parent().get_parent().margin_top = 0
	return false


func _process(delta):
	if shake_timer > 0:
		shake_timer -= delta
		rect_position = Vector2.ZERO
		if shake_timer > 0:
			rect_position += Vector2(rand_range(-1.0, 1.0) * shake_amount,\
					 rand_range(-1.0, 1.0) * shake_amount)

	if idle and texture is AnimatedTexture:
		blink_timer -= delta
		if blink_timer < 0:
			play_portrait_anim()
			set_blink_timer()


func set_blink_timer():
	randomize()
	blink_timer = lerp(blink_freq_min, blink_freq_max, randf())


# following functions are triggered by signals from VoiceGenerator
func _on_voice_starting():
	if not idle and portrait_mode == PLAY_WITH_VOICE:
		play_portrait_anim()

func _on_voice_finished(): 
	if not idle and portrait_mode == PLAY_WITH_VOICE:
		stop_portrait_anim()

func _on_voice_paused(): 
	if not idle and portrait_mode == PLAY_WITH_VOICE and sync_anim:
		pause_portrait_anim()

func _on_voice_resumed(): 
	if not idle and portrait_mode == PLAY_WITH_VOICE and sync_anim:
		play_portrait_anim()

func _on_voice_speed_changed(new_speed: int): 
	if not idle and portrait_mode == PLAY_WITH_VOICE and sync_anim:
		set_portrait_anim_speed(new_speed)


# triggered by signals from Dialogue (parent node)
func _on_characters_printed(charas: String):
	if idle or not active or portrait_mode != PLAY_WITH_TEXT or not texture is AnimatedTexture:
		return
	if not (paused() or sync_anim):
		return
	
	var pause = true
	for chara in charas:
		if paused() and not chara in NON_PHOENETIC:
			play_portrait_anim()
			return
		if not chara in PAUSE_CHARAS:
			pause = false
	if sync_anim and pause:
		pause_portrait_anim()

func _on_printing_finished(_block):
	if not idle and portrait_mode == PLAY_WITH_TEXT:
		stop_portrait_anim()

func _on_printing_speed_changed(new_speed: int):
	if not idle and portrait_mode == PLAY_WITH_TEXT and sync_anim:
		set_portrait_anim_speed(new_speed)


# called by above reciever methods.
func play_portrait_anim():
	if texture is AnimatedTexture:
		texture.set_pause(false)
		texture.set_current_frame(0)

func pause_portrait_anim():
	if texture is AnimatedTexture:
		texture.set_pause(true)
		texture.set_current_frame(texture.get_frames() - 1)

func stop_portrait_anim(): # switches to idle portrait if defined. otherwise, same as pausing.
	if idle_portrait_path:
		idle = true
		load_portrait(idle_portrait_path)
		blink_timer = blink_freq_min # stopped clock illusion.
	else: pause_portrait_anim()

func set_portrait_anim_speed(new_speed: int): # like speech speed, uses a scale of 1 - 9, where 0 resets the default.
	if texture is AnimatedTexture:
		if new_speed == 0:
			texture.fps = original_fps
		else:
			var fps = 2 * new_speed # you can change this formula to change the minimum and maximum speeds.
			texture.fps = int(fps)

# other.
func paused() -> bool:
	if not texture is AnimatedTexture:
		return false
	return texture.get_pause()

func shake (shake: String):
	match shake:
		'shake_weak_short':
			shake_amount = shake_weak
			shake_timer = shake_short
		'shake_weak_medium':
			shake_amount = shake_weak
			shake_timer = shake_medium
		'shake_weak_long':
			shake_amount = shake_weak
			shake_timer = shake_long
		'shake_regular_short':
			shake_amount = shake_regular
			shake_timer = shake_short
		'shake_regular_medium':
			shake_amount = shake_regular
			shake_timer = shake_medium
		'shake_regular_long':
			shake_amount = shake_regular
			shake_timer = shake_long
		'shake_strong_short':
			shake_amount = shake_strong
			shake_timer = shake_short
		'shake_strong_medium':
			shake_amount = shake_strong
			shake_timer = shake_medium
		'shake_strong_long':
			shake_amount = shake_strong
			shake_timer = shake_long
		var invalid:
			print("Invalid animation name ", invalid)
