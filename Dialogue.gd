"""
Expanded Godot Open Dialogue - Non-linear conversation system
for Godot 3.2
Version "New Blade Cuts Real Clean"

Animated sprite, signals, variable text speed, format string, expressions, 
input blocking, functionality, refactoring, integration with Godot Voice Generator, etc.
By Graham Overby, 8/2020.
twitter/tumblr: @grahamoverby
overby.gr@gmail.com

Original Godot Open Dialogue Author: J. Sena
License: CC-BY
URL: https://jsena42.bitbucket.io/god/
Repository: https://bitbucket.org/jsena42/godot-open-dialogue/

Godot Voice Generator
By TNTC Labs
https://tntc-lab.itch.io/
"""

extends Control

signal dialogue_started(first_block)
signal block_started(block)
signal block_complete(last_block, next_block)
signal dialogue_complete(last_block)
signal custom_signal(block, arg_array)
signal printing_finished(block)
signal printing_speed_changed(new_speed)
signal characters_printed(string)

enum {INDEFINITE, PLAY_WITH_VOICE, PLAY_WITH_TEXT} # animation loop modes. see DEFAULT_PORTRAIT_ANIM_MODE, line 86
const Portrait = preload("res://addons/Godot Open Dialogue/Portrait.gd")
const CHOICE_SCENE = preload('Choice.tscn') # Base scene for question choices

## Required nodes ##
onready var box : Control = $Box # The container node for all GUI elements.
onready var hbox = $Box/HBoxContainer # By default, contains portraits, dialogue RichTextLabel, and question box.
onready var tween : Tween = $Tween
onready var animations : AnimationPlayer = $AnimationPlayer
onready var label : RichTextLabel = $Box/HBoxContainer/Container1/Container2/RichTextLabel # The label where the text will be displayed.
onready var background : Panel = $Box/Panel # This is seperate from the rich text lable so it won't be drawn over the portraits.
	# You can change the tree order and node paths if you want the portraits to be behind/above the dialogue box instead of inside.
onready var choices : VBoxContainer = $Box/HBoxContainer/ScrollContainer/ScrollContainer1/ScrollContainer2/Choices # The container node for the choices.
#onready var choice_frame : ScrollContainer = $Box/HBoxContainer/ScrollContainer/ScrollContainer1 # The frame for the scrollbar for the choices.
onready var choice_container : VBoxContainer = $Box/HBoxContainer/ScrollContainer
onready var continue_indicator : ColorRect = $Box/ContinueIndicator # Blinking square displayed when the text is all printed.
onready var sprite_left : Portrait = $Box/HBoxContainer/SpriteLeftContainer/SpriteLeft # I changed these to TextureRects so they could fit into an adaptive GUI
onready var sprite_right : Portrait = $Box/HBoxContainer/SpriteRightContainer/SpriteRight
onready var name_left : Label = $Box/NameLeft
onready var name_right : Label = $Box/NameRight
# Autoloads (though I guess they don't have to be autoloads) # 
onready var cutscene_manager = PROGRESS # Node that holds functions called during cutscenes (default object used for function calls and expression blocks)
onready var game_data = PROGRESS # Node where the interaction log, quest variables, inventory and other useful data should be accessible.
const DIALOGUES_DICT = 'dialogues' # The dictionary in 'game_data' used to keep track of whether / how many times an interaction has occured.

## Optional node for integration with Godot Voice Generator ##
const VoiceGenerator = preload("res://addons/Voice Generator/VoiceGeneratorAudioStreamPlayer.gd")
var voice_generator : VoiceGenerator
# If you're not using the voice generator, just comment out the above two lines and uncomment this one:
#var voice_generator = null

##### SETUP #####

## Paths ##
const DIALOGUES_FOLDER = 'res://dialogues/' # Path to folder where the JSON files will be stored
const THEMES_FOLDER = 'res://styles/' # path to folder holding theme resources (optional, can leave empty if not using)
const FONT_FOLDER = 'res://fonts/'
const INLINE_IMAGE_FOLDER = 'res://dialogue_icons/' # optional; will be added on front of every inline image path specified in [img]
const INLINE_IMAGE_SUFFIX = '.png' # optional; will be added at the end of every inline image path specified in [img]

#Interface
var advance_command : String = 'ui_accept' # added button for triggering next() to advance dialogue
var complete_command : String = 'ui_accept' # button for automatically completing text. can be the same as above.
var scroll_up_command : String = 'ui_focus_prev' # for manual scrolling in cases where text is larger than text box
var scroll_down_command : String = 'ui_focus_next'
const ALWAYS_BLOCK_INPUTS : bool = true

## Typewriter effect ##
var pause_char : String = '|' # The character used in the JSON file to define where pauses should be. Doesn't appear in the dialogue.
				# can also be used to insert the value from the index of a dictionary into the text, e.g., -- |dictionary_name|key_name|
				# to do this, you must specify the dictionaries used in an array 'dictionaries' within the block.
				# if only one dictionary is specified in dictionaries, you can just use |key_name| within the text.
var default_wait_time : float = 0.025 # Default time interval (in seconds) between characters for typewriter effect. Set to 0 to disable it. 
				# This value can be changed temporarily in a text block to speed up or slow down text.
				# by following the pause_char (see above) with a single-digit number, e.g., 6|
				# 0| disables typewriter effect until the next | is reached, and
				# -| (dash-pause_char) resets the speed to the default.
var default_pause_time : float = 0.25 # Duration of each pause when the typewriter effect is active. 
const PAUSE_ON_PUNCTUATIONS := ['.', '!', '?', '-'] # leave empty to disable pausing on punctuation.
var line_count : int = 5 # max number of text lines visible at once (used to snap to nearest line when scrolling)

## Other options ##
var language := 'ENG' # multiple language support
var ENABLE_VOICE := true # integration with Godot Voice Generator
const SCROLL_BEFORE_ADVANCE := true # animation of text scrolling up when advancing to next dialogue block, a la final fantasy
const ALWAYS_AUTOSCROLL := false  # Enable or disable autoscrolling for text blocks larger than the dialogue box;
# might cause performance issues due to repeatedly editing BBcode text (this is the only way to create 
# a autoscroll effect), but if disabled, it's on you to make sure each block is short enough to fit. 
# my suggestion is to only use it for messages where you NEED long blocks of text, which you can
# do by including 'autoscroll: true' in one of your blocks and leaving this constant false.
const SHOW_NAMES_DEFAULT := true # Default for character name labels (can be changed in JSON by including "show_names: true" or "false" in a "styles" object
const FIT_INLINE_IMAGES := true # if true, inline images will automatically be resized to the same height as the font, while preserving aspect ratio.
const DEFAULT_FRAME_POSITION : String = 'bottom' # Use to 'top' or 'bottom' to change the dialogue frame vertical alignment
						# can be changed for current line by adding parameter "alignment", e.g. alignment:"top" 
var box_margin := 25 # Vertical space (in pixels) between the dialogue box and the window border
var choice_text_alignment : String = 'left' # Alignment of the choice's text within the text box. Can be 'left' or 'right'
var alternate_choice_node_alignment : bool = true # if true, choice list will appear opposite avatar. if false, it will stay on the right.
const CHOICE_LINES_ON_SCREEN : int = 5 # max number of lines visible at once in choice box. if there are more than this number, the player will have to scroll. set to zero to disable.
var enable_continue_indicator := true # Enable or disable the 'continue_indicator' animation when the text is completely displayed. If typewritter effect is disabled it will always be visible on every dialogue block.

var active_choice := Color(1.0, 1.0, 1.0, 1.0)
var inactive_choice := Color(1.0, 1.0, 1.0, 0.5)
var move_distance = 100
var ease_in_speed = 0.25
var ease_out_speed = 0.50

var portrait_presets : Dictionary = {
	"Jimmy":"jimmy/speaking.tres"
}
var idle_portrait_prests: Dictionary = {
	"Jimmy":"jimmy/idle.tres"
}
var color_presets: Dictionary = {
	"phthalo":"#000F89",
	"sepia":"#704214"
}
var default_bb_open_tag = ""
var default_bb_close_tag = ""

# END OF SETUP #

# more variables added by graham 
var timer := -60.0 # this is the value whenever the timer is not running.
var pause_time := default_pause_time
var wait_time := default_wait_time # to allow text speed to be altered during runtime
var prev_positions: Dictionary = {} #track previous positions of characters by name
var prev_portraits: Dictionary = {} #same for portraits
var prev_idle_portraits: Dictionary = {}
var prev_block : Dictionary # previous dialogue block
var autoscroll : bool = ALWAYS_AUTOSCROLL
var show_names := SHOW_NAMES_DEFAULT
var index : int # because I'm using array rather than object to hold the blocks
# (each JSON contains a key for each language needed, with the value for each 
# key being an array of all the blocks of dialogue in that language)
#so it was necessary to track current index rather than a reference to current block
var BB_text := ''
var BB_text_index := 0
var speed_changes := {} # holds indexes where text should change speed 
var executing := false # true when expressions are being executed, to prevent advancement
onready var DEFAULT_THEME = box.get_theme()
var input_blocking := ALWAYS_BLOCK_INPUTS
var disable_advance := false

# Original Default values. Don't change them 
var id: String # (of the JSON file)
var dialogue = [] # (array of all blocks in the selected language)
var next_blockID = '' # dynamically typed; can be a string, int, or array
var pause_array := [] # holds spots in phrase where printing should pause 

func _ready():
	#uncomment the following 5 lines as needed.
#	connect("block_started", cutscene_manager, '_on_block_started')
#	connect("block_complete", cutscene_manager, '_on_block_complete')
#	connect("dialogue_started", cutscene_manager, '_on_dialogue_started')
#	connect("dialogue_complete", cutscene_manager, '_on_dialogue_complete')
#	connect("custom_signal", cutscene_manager, '_on_custom_dialogue_signal')
	for node in [sprite_left, sprite_right]:
		connect("printing_finished", node, "_on_printing_finished")
		connect("printing_speed_changed", node, "_on_printing_speed_changed")
		connect("characters_printed", node, "_on_characters_printed")	
	if ENABLE_VOICE:
		for node in [sprite_left, sprite_right]:
			voice_generator.connect("finished_phrase", node, "_on_voice_finished")
			voice_generator.connect("starting_phrase", node, "_on_voice_starting")
			voice_generator.connect("pause", node, "_on_voice_paused")
			voice_generator.connect("resume", node, "_on_voice_resumed")
			voice_generator.connect("speed_changed", node, "_on_voice_speed_changed")
	
	label.get_parent().rect_min_size.y = box.rect_min_size.y
		# this is necessary because the label container can't be set to expand (or it will grow to the same height as portraits).
	set_frame(DEFAULT_FRAME_POSITION)
	continue_indicator.hide()
	choice_container.hide()
	sprite_left.hide()
	sprite_right.hide()
	name_left.hide()
	name_right.hide()
	box.hide()
	hide()
	


func initiate(file_id, first_block = 'start'): # Load the whole dialogue into a variable
	if executing: # this prevents errors caused by multiple Initiate() calls in quick succession
		return
	executing = true
	
	id = file_id
	var file = File.new()
	var path = str(id + ".json")
	path = DIALOGUES_FOLDER.plus_file(path)
	var error = file.open(path, file.READ)
	if error:
		print("error opening file at ", path, ": ", error)
	var json = JSON.parse(file.get_as_text()).result
	file.close()
	
	if not json.has(language):
		print("error: language ", language, " not found in file ", file_id)
		return
	dialogue = json[language]
	if not dialogue is Array:
		print("error: blocks must be formatted as an array in each language.")
		return
	
	for i in dialogue.size():
		if dialogue[i] is String:  #this code allows a block to be just a String 
			dialogue[i] = { "content":dialogue[i] }
		elif dialogue[i] is Dictionary:
			for key in dialogue[i]:
				if key is String: 
					var new_key = key.strip_edges() # i wish godot did this automatically
					dialogue[i][new_key] = dialogue[i][key]
					dialogue[i].erase(dialogue[i][key])
	
	if not game_data.get(DIALOGUES_DICT).has(id): # Checks if it's the first interaction.
		game_data.get(DIALOGUES_DICT)[id] = {}
	
	emit_signal("block_started", first_block)
	if first_block == 'start' and index_from_ID('start') == -1: 
		#if no theres no block with ID 'start', it should just start at index 0
		first_block = 0
	
	index = first_block if first_block is int else index_from_ID(first_block)
	update_dictionaries(dialogue[index])
	dialogue[index] = infer_missing(dialogue[index])
	
	show()
	update_dialogue(dialogue[index])


func set_frame(frame_position: String): # Mostly aligment operations.
	var frame_height: int = box.rect_min_size.y
	match frame_position:
		'top':
			box.anchor_top = 0
			box.anchor_bottom = 0
			box.margin_top = box_margin
			box.margin_bottom = frame_height + box_margin
		'bottom':
			box.anchor_top = 1
			box.anchor_bottom = 1
			box.margin_top = -frame_height - box_margin
			box.margin_bottom = -box_margin
		'middle':
			box.anchor_top = 0.5
			box.anchor_bottom = 0.5
			box.margin_top = -frame_height / 2
			box.margin_bottom = frame_height / 2
		var invalid:
			print("invalid frame position ", invalid, " at dialogue index ", index)


func clean(): # Resets variables between every block.
	label.get_v_scroll().ratio = 0 # (scrolls all the way to the top)
	label.scroll_following = autoscroll
	label.bbcode_text = ''
	next_blockID = null #setting to null prevents user from skipping through a dialogue that has a question or expression
	continue_indicator.hide()
	animations.stop()
	pause_array = []
	speed_changes = {}
	wait_time = default_wait_time
	pause_time = default_pause_time
	BB_text_index = 0
	sprite_left.clean()
	sprite_right.clean()
	if ENABLE_VOICE:
		voice_generator.stop()


func reset_defaults(): # resets variables after every dialogue.
	prev_portraits = {}
	prev_idle_portraits = {}
	prev_positions = {}
	autoscroll = ALWAYS_AUTOSCROLL 
	input_blocking = ALWAYS_BLOCK_INPUTS
	disable_advance = false
	set_frame(DEFAULT_FRAME_POSITION)
	background.modulate = Color.white
	show_names = SHOW_NAMES_DEFAULT
	for node in [label, name_left, name_right, background, choice_container]:
		node.set_theme(DEFAULT_THEME)


func index_from_ID(blockID) -> int:
	# I added this so i could use JSONS set up as arrays of objects rather than
	# objects containing objects. Also so i could make "repeat" its own parameter. 
	# i know it's ugly.
	# also, i changed  DIALOGUES_DICT to a 2D dictionary (of block IDs storing 
	# ints) rather than a 1D dictionary of bools. the int gets incremented
	# whenever the block with the given ID is accessed (including 'start').
	# also, works with a string ID or integer index -Graham
	if str(blockID).is_valid_integer(): # necessary because for some reason ints are always read as floats.
		return str(blockID).to_int() # presumed to be a valid index
	
	if game_data.get(DIALOGUES_DICT)[id].has(blockID):
		#search for a repeat block whose number matches the number
		#stored in the dictionary for this block ID, and increment
		game_data.get(DIALOGUES_DICT)[id][blockID] += 1
		var targetRepeats = game_data.get(DIALOGUES_DICT)[id][blockID]
			# (number of times this block ID has been repeated)
		var repeatIndex = -1 # stays -1 if file does not contain any 'repeat's
		var highestNumberFound = -1
		for i in dialogue.size():
			var block = dialogue[i]
			if block.has('repeat') and block.has('id') and block['id'] == blockID: # ID matches and block has repeat 
				var blockRepeats
				if str(block['repeat']).is_valid_integer():
					blockRepeats = str(block['repeat']).to_int()
				else: 
					blockRepeats = 0
				if blockRepeats <= targetRepeats and blockRepeats > highestNumberFound: 
					# gets index of highest repeat number that is <= the asked-for number
					repeatIndex = i
					highestNumberFound = blockRepeats
					
		if repeatIndex >= 0:
			return repeatIndex
	else:
		game_data.get(DIALOGUES_DICT)[id][blockID] = 0 #first time using this blockID
	#following runs if there are no repeat blocks for this ID, OR this is the first 
	#time this ID has been used (AND the blockID is a string)
	for i in dialogue.size():
		var block = dialogue[i]
		if block.has('id') and block['id'] == blockID:
			return i
	print("no index found for ", blockID, " in ", id)
	return -1 # if the ID doesn't exist at all
	

func update_dictionaries(block: Dictionary) -> void:
	#added automatic setting (alternating) and storing position by name in dict
	var blockname = ""
	if block.has('name'):
		blockname = block['name']
	elif prev_block.has('name'):
		blockname = prev_block['name']
	else: return
	
	if block.has('position'):
		prev_positions[blockname] = block['position']
	if block.has('portrait'):
		prev_portraits[blockname] = block['portrait']
	if block.has('idle_portrait'):
		prev_idle_portraits[blockname] = block['idle_portrait']


func infer_missing(block: Dictionary) -> Dictionary:
	#  the keys mentioned in this function are the ones you can rely on each block to have.
		
	#infer name
	if not block.has('name'):
		if prev_block.has('name'):
			block['name'] = prev_block['name']
		else:
			block['name'] = ''
	
	#infer portrait: check (1) if character is same as last block (2) if character has appeared before in dialogue, (3) if character has a preset
	if not block.has('portrait'):
		if not block['name']:
			block['portrait'] = ''
		elif prev_block.has('name') and prev_block.has('portrait') and \
		block['name'] == prev_block['name']:
			block['portrait'] = prev_block['portrait']
		elif prev_portraits.has(block['name']):
			block['portrait'] = prev_portraits[block['name']]
		elif portrait_presets.has(block['name']):
			block['portrait'] = portrait_presets[block['name']]
		else:
			block['portrait'] = ''
	if not block.has('idle_portrait'):
		if not block['name']:
			block['portrait'] = ''
		if prev_block.has('name') and prev_block.has('idle_portrait') and \
		block['name'] == prev_block['name']:
			block['idle_portrait'] = prev_block['idle_portrait']
		elif prev_idle_portraits.has(block['name']):
			block['idle_portrait'] = prev_idle_portraits[block['name']]
		elif idle_portrait_prests.has(block['name']):
			block['idle_portrait'] = idle_portrait_prests[block['name']]
		else:
			block['idle_portrait'] = ''
			
	#infer position
	if not block.has('position') and block['name']:
		if prev_block.has('name') and block['name'] == prev_block['name']:
			block['position'] = prev_block['position']
		elif prev_positions.has(block['name']):
			block['position'] = prev_positions[block['name']]
	if not block.has("position"):
		if prev_block.has('position') and prev_block['position'] == 'left':
			block['position'] = 'right'
		else: # these two clauses are to have speakers alternate between left and right
			  # if there is no other way to determine the position
			block['position'] = 'left'
	
	return block


func update_dialogue(block: Dictionary): # the core function, which runs whenever a new dialogue block is loaded.
	clean()
	emit_signal("block_started", block)
	check_type(block)

	if block.has('autoscroll') and block['autoscroll'] is bool:
		autoscroll = block['autoscroll']
		label.scroll_following = block['autoscroll']
	if block.has('block_inputs') and block['block_inputs'] is bool:
		input_blocking = block['block_inputs']
	if block.has('disable_advance') and block['disable_advance'] is bool:
		disable_advance = block['disable_advance']
	
	if block.has('options'):
		check_answers(block)
	if block.has('content'):
		box.show()
		block['content'] = format_content(block)
		block['no_BB_content'] = set_text_box(block['content'])
	else: box.hide()
	if block.has('signal'):
		var arg_array = block['signal']
		emit_signal("custom_signal", block, arg_array)
	check_sprites(block)
	check_style(block)
	check_voice(block)
	
	var await := true
	if block.has('await') and block['await'] is bool:
		await = block['await']
	var function = check_expressions(block)
	if function is GDScriptFunctionState and await:
		yield(function, "completed")
	# Next_BlockID will be set by the expression result (if 'results') or by user's 
	# selection (if 'options'). Or has been set by check_type. Otherwise, it is set here:
	if not (next_blockID or block.has('results') or block.has('options')):
		if block.has('next'):
			next_blockID = block['next']
		else:
			next_blockID = ''
			# An empty string will automatically advance to the next block in the array.
	executing = false
	if not block.has('content') and next_blockID != null:
		print("autonext!!!")
		next()


func check_type(block: Dictionary):
	# compatibility with block types in original code.
	if not block.has('type'):
		return
	if block['type'] == 'divert':
		if not block.has('variable') or not block.has('dictionary'):
			print("need to define target variable and dictionary in block ", index)
			return
		if not game_data.get(block['dictionary']).has(block['variable']):
			print("variable ", block['variable'], " not found in ", block['dictionary'], " for block ", index)
			return
		var boolean
		var variable = game_data.get(block['dictionary'])[block['variable']]
		match block['condition']:
			'boolean':
				boolean = variable
			'equal':
				boolean = (variable == block['value'])
			'greater':
				boolean = (variable > block['value'])
			'less':
				boolean = (variable < block['value'])
			'range':
				boolean = (variable > (block['value'][0] - 1)) \
						and (variable < (block['value'][1] + 1))
			'_':
				print("invalid condition in block ", index)
				return
		if boolean and block.has('true'):
			next_blockID = block['true']
		elif not boolean and block.has('false'):
			next_blockID = block['false']
		elif not boolean:
			next_blockID = 'end' # if no next block is specified for false, end dialogue
			
	elif block['type'] == 'action':
		if block.has('value') and block.has('dictionary'):
			update_variable(block['variables'], block['dictionary'])


func format_content(block: Dictionary) -> String:
	var content : String = block['content']
	# replaces placeholder phrases in the passed string. also reformats image tags if enabled.
	if block.has('dictionaries'):
		var placeholder = str(pause_char + '_' + pause_char)
		var array = [block['dictionaries']] if block['dictionaries'] is String \
			else block['dictionaries']
		#allows a string instead of array if using just one dictionary
		for dict_name in array:
			var dict = game_data.get(dict_name)
			if not dict:
				print("error: dictionary ", dict_name, " not found in dialogue index ", index)
				continue
			for key in dict:
				var keystring = str(dict_name + pause_char + key) \
					if array.size() > 1 else key
					# no need to specify dictionary name if only using one dictionary.
				content = content.format([[keystring, dict[key]]], placeholder)
	
	# replaces shorthand font paths
	if FONT_FOLDER and content.find("[font") != -1:
		var fonttagindex = content.find("[font")
		while(fonttagindex != -1):
			var font_name_index = content.find('=', fonttagindex) + 1
			var fonttagend = content.find("]", fonttagindex)
			var font_name_length = fonttagend - font_name_index
			var font_path = content.substr(font_name_index, font_name_length).strip_edges()
			var new_font_path = FONT_FOLDER.plus_file(str(font_path + '.tres'))
			content = content.replace(font_path, new_font_path)
			fonttagindex = content.find("[font", fonttagend)
	
	# replaces color names with defined presets
	if color_presets.keys() and content.find("[color") != -1:
		var colortagindex = content.find("[color")
		while(colortagindex != -1):
			var color_name_index = content.find('=', colortagindex) + 1
			var color_tag_end = content.find("]", colortagindex)
			var color_name_length = color_tag_end - color_name_index
			var color_name = content.substr(color_name_index, color_name_length).strip_edges()
			if color_name in color_presets:
				content = content.replace(color_name, color_presets[color_name])
			else:
				print("Error: no color preset exists for ", color_name, " in dialogue index ", index)
			colortagindex = content.find("[color", color_tag_end)
	
	#replaces shorthand inline image paths, and auto-scales inline images
	if (FIT_INLINE_IMAGES or INLINE_IMAGE_FOLDER or INLINE_IMAGE_SUFFIX) and content.find("[img") != -1:
		var char_height := 0
		if FIT_INLINE_IMAGES:
			var font: Font
			if label.theme:
				font = label.theme.get_font("normal_font", "RichTextLabel")
			elif box.theme:
				font = box.theme.get_font("normal_font", "RichTextLabel")
			char_height = font.get_char_size(ord('|')).y
		
		var imagetagindex = content.find("[img]")
		while(imagetagindex != -1):
			var imagetagend = content.find("[/img]", imagetagindex)
			var imagetaglength = imagetagend - imagetagindex + "[/img]".length()
			var imagetagstring = content.substr(imagetagindex, imagetaglength)
			var image_path = imagetagstring.strip_edges().lstrip("[img]").rstrip("[/img]")
			
			var new_image_path = INLINE_IMAGE_FOLDER.plus_file(str(image_path + INLINE_IMAGE_SUFFIX))
			var size = load(new_image_path).get_size()
			if FIT_INLINE_IMAGES and size.y > char_height:
				size *= char_height/size.y
				size = size.round()
			var newtagstring = str('[font=res://addons/Godot Open Dialogue/image_offsetter.tres][img=', \
					size.x, 'x', size.y, ']', new_image_path, '[/img][/font]')
			content = content.replace(imagetagstring, newtagstring)
			imagetagindex = content.find("[img]")
	
	if default_bb_open_tag and default_bb_close_tag:
		content = str(default_bb_open_tag, content, default_bb_close_tag)
	return content


func set_text_box(BBphrase: String) -> String: 
	# this sets the parameters for the RichTextLabel based on whether autoscroll is on,
	# and applies text to it, after filtering out pause characters
	# also returns version of string without BBCode. this is awful, I know.
	# in my defense I did not know about RegEx when I wrote this.
	var search
	label.bbcode_text = BBphrase
	# gets text without BBCode tags for purposes of determining pauses (this is not for display purposes)
	# ( this is only necessary for non-scrolling mode, which uses visible_characters)
	var no_BB_phrase = label.text
	
	if not autoscroll:
		# its necessary to remove the return characters, since visible_characters
		# counts them as one character and not two.
		var plain_phrase = no_BB_phrase
		search = plain_phrase.find('\n')
		if search >= 0:
			while search != -1:
				plain_phrase.erase(search,1)
				search = plain_phrase.find('\n')
		# with the returns removed, we can generate the array of pauses and speed changes.
		# again, this string is never displayed; it's just for making the arrays.
		search = plain_phrase.find(pause_char)
		if search >= 0:
			while search != -1:
				# checks if the | is a pause or a speed modifier, e.g., 2|
				if plain_phrase[search - 1].is_valid_integer():
					speed_changes[search - 1] = int(plain_phrase[search - 1])
					plain_phrase.erase(search - 1, 2)
				elif plain_phrase[search - 1] == '-':
					speed_changes[search - 1] = ''
					plain_phrase.erase(search - 1, 2)
				else:
					pause_array.append(search)
					plain_phrase.erase(search, 1)
				search = plain_phrase.find(pause_char)
	
	# even if the above code executed, we still have to get rid of the pause 
	# chars in the version WITH BBcode so we can give it to the label (the 
	# indexes of the pause chars won't be the same in both due to the BBcode tags). 
	# for the scrolling version, this is also what generates the pause array,
	search = BBphrase.find(pause_char)
	if search >= 0:
		while search != -1:
			# checks if the | is a pause or a speed modifier, e.g., 5|
			if BBphrase[search - 1].is_valid_integer():
				if autoscroll:
					speed_changes[search - 1] = int(BBphrase[search - 1])
				BBphrase.erase(search - 1, 2)
			elif BBphrase[search - 1] == '-':
				if autoscroll:
					speed_changes[search - 1] = ''
				BBphrase.erase(search - 1, 2)
			else:
				if autoscroll:
					pause_array.append(search)
				BBphrase.erase(search, 1)
			search = BBphrase.find(pause_char)
	
	if default_wait_time > 0: # Check if the typewriter effect is active and then starts the timer.
		if not autoscroll:
			label.bbcode_text = BBphrase
			label.visible_characters = 0
		else: # autoscroll
			label.bbcode_text = ''
			label.visible_characters = -1 # shows all characters
			BB_text = BBphrase
		timer = wait_time
	else: complete_text()
	return no_BB_phrase


func load_theme(theme_name: String) -> Theme:
	var path = THEMES_FOLDER.plus_file(str(theme_name + '.tres'))
	var loaded_theme = load(path)
	if not loaded_theme or not loaded_theme is Theme:
		print("invalid theme path, ", path, " at dialogue index ", index)
		return null
	return loaded_theme


func check_style(block: Dictionary): # also handles alignment and opacity.
	if block.has('style') and block['style'] is Dictionary:
		var style_dict = block['style']
		
		if style_dict.has('frame_opacity'):
			if not (style_dict['frame_opacity'] is float or style_dict['frame_opacity'].is_valid_float()):
				print("invalid frame opacity setting in dialogue index ", index)
			else:
				var new_color = Color.white
				new_color.a = style_dict['frame_opacity']
				background.modulate = new_color 
		if style_dict.has('alignment') and style_dict['alignment'] is String:
			set_frame(style_dict['alignment'].to_lower())
		if style_dict.has('show_names') and style_dict['show_names'] is bool:
			show_names = style_dict['show_names']
		
		if style_dict.has('theme'):
			var newtheme = load_theme(style_dict['theme'])
			if newtheme:
				for node in [label, name_left, name_right, background, choice_container]:
					node.set_theme(newtheme)
		if style_dict.has('names_theme'):
			var newtheme = load_theme(style_dict['names'])
			if newtheme:
				name_right.set_theme(newtheme)
				name_left.set_theme(newtheme)
		if style_dict.has('frame_theme'):
			var newtheme = load_theme(style_dict['frame_theme'])
			if newtheme:
				background.set_theme(newtheme)
		if style_dict.has('text_theme'):
			var newtheme = load_theme(style_dict['text_theme'])
			if newtheme:
				label.set_theme(newtheme)
		if style_dict.has('options_theme'):
			var newtheme = load_theme(style_dict['text_theme'])
			if newtheme:
				choice_container.set_theme(newtheme)
		
	elif block.has('style') and block['style'] is String and block['style'] == 'default':
		set_frame(DEFAULT_FRAME_POSITION)
		background.modulate = Color.white
		show_names = SHOW_NAMES_DEFAULT
		for node in [label, name_left, name_right, background, choice_container]:
			node.set_theme(DEFAULT_THEME)
			
	if not show_names or not block['name']: # to avoid empty text box.
		name_left.hide()
		name_right.hide()
	elif block['position'] == 'left':
		name_left.text = block['name']
		yield(get_tree(), 'idle_frame')
		name_left.show()
		name_left.rect_size.x = 0
		name_right.hide()
	else: # position = right
		name_right.text = block['name']
		yield(get_tree(), 'idle_frame')
		name_right.show()
		name_right.rect_size.x = 0
		name_left.hide()


func check_sprites(block: Dictionary):
	sprite_left.rect_position = Vector2.ZERO
	sprite_right.rect_position = Vector2.ZERO
	if not block['portrait']: # allows passing empty string to hide portraits
		sprite_left.deactivate()
		sprite_right.deactivate()
		return
		
	var active_sprite 
	var inactive_sprite
	if block['position'] == 'left':
		active_sprite = sprite_left
		inactive_sprite = sprite_right
	else: # block['position'] == 'right':
		active_sprite = sprite_right
		inactive_sprite = sprite_left
	
	if block.has('portrait_mode') and block['portrait_mode'] is String:
		active_sprite.set_portrait_mode(block['portrait_mode'])
	if block.has('sync_animation') and block['sync_animation'] is bool:
		active_sprite.sync_anim = block['sync_animation']
	if block.has('idle_portrait') and block['idle_portrait'] is String:
		active_sprite.idle_portrait_path = block['idle_portrait']
	
	var error = active_sprite.load_portrait(block['portrait'])
	if error:
		print("Failed to load sprite in dialogue index ", index)
	active_sprite.activate()
	inactive_sprite.deactivate()
	# i don't know why this has to be set manually every time
	#yield(get_tree(),"idle_frame")
	#active_sprite.get_parent().rect_size = Vector2(0,0)#.call_deferred("hide")
	#active_sprite.get_parent().set_alignment(2) #call_deferred("show")
	# altered code so that "animation_in"/"out" needn't be included, and animation doesn't need portrait
	if block.has('animation_in'):
		start_animation(block['position'], block['animation_in'])


func check_voice(block: Dictionary):
	if not ENABLE_VOICE:
		return
	if (block.has('voice') and block['voice'].empty()) or block['name'].empty():
		return # can pass empty 'voice' field for mute block
	
	# completely new settings
	if block.has('voice') and block['voice'] is Dictionary:
		var new_name = block['name'] if block.has('name') else ""
		var new_pitch = float(block['voice']['pitch']) if block['voice'].has('pitch') else null
		var file = block['voice']['file'] if block['voice'].has('file') else ""
		var pitch_variation = float(block['voice']['pitch_variation']) if \
				block['voice'].has('pitch_variation') else null
		var speed = float(block['voice']['speed']) if block['voice'].has('speed') else null
		var volume = float(block['voice']['volume']) if block['voice'].has('volume') else null
		voice_generator.new_voice(new_name, new_pitch, file, volume, speed, pitch_variation)
	else:
		# using a preset voice
		var voice_name = null
		if block.has('voice') and block['voice'] is String:
			voice_name = block['voice']
		elif block['name']: 
			voice_name = block['name']
		if voice_name != null:
			voice_generator.set_voice(voice_name)
	
	# you can include one of these parameters to adjust pitch/volume of the current voice
	if block.has('pitch_adjustment'):
		voice_generator.adjust_pitch(float(block['pitch_adjustment']))
	if block.has('volume_adjustment'):
		voice_generator.adjust_volume(float(block['volume_adjustment']))
	if block.has('no_BB_content'):
		voice_generator.read(block['no_BB_content'])


func check_expressions(block: Dictionary) -> void:
	if not block.has('expression') or not block['expression'] is String:
		return
	
	var object = cutscene_manager
	if block.has('object'):
		object = get_node(block['object'])
		if !object:
			print('Error: unable to find object at path ', block['object'], ' in dialogue index ', index)
			return
	
	var exp_array = block['expression'].split('\n', false)
	var last_result
	for line in exp_array:
		if line[0] == '#': # line is commented out.
			continue
		var wait := true
		if line[0] == '>': # character used to indicate concurrent processing (do not yield)
			line = line.trim_prefix('>')
			wait = false
		
		var result = execute_expression(line, object)
		if result is GDScriptFunctionState and wait:
			result = yield(result, "completed")
		if result != null and not result is GDScriptFunctionState:
			last_result = result
	
	if block.has('results') and block.has('next'):
		if not (block['results'] is Array and block['next'] is Array):
			print("Error: 'results' and 'next' must be arrays for 'results' to be used")
			return
		for index in block['results'].size():
			var option = block['results'][index]
			if str(last_result) == str(option):
				next_blockID = block['next'][index]
		if not next_blockID and block['next'].size() > block['results'].size(): 
			# can add an extra element to 'next' as wildcard (works like _: in a match statement)
			next_blockID = block['next'].back() # wildcard, bitches!!


func execute_expression(line: String, object: Object):
	var expression = Expression.new()
	var error = expression.parse(line, [])
	if error:
		print("Error parsing expression, ", line, " at dialogue index ", index, ": ", error)
		return null
	yield(get_tree(), "idle_frame")
	var output = expression.execute([], object)
	if output is GDScriptFunctionState:
		output = yield(output, "completed")
		
	if expression.has_execute_failed():
		print("Error executng expression, ", line, " at dialogue index ", index)
		return null
	return output


func next(): # uses member variables, needs no arguments
	if next_blockID == null or executing:
		return # next_blockID is set to null whenever waiting for a player to select an
		#answer to a question (prevents accidental selection when mashing through text)
	
	executing = true
	var block = dialogue[index]
	if block.has('animation_out'):
		start_animation(block['position'], block['animation_out'])
	if SCROLL_BEFORE_ADVANCE:
		label.scroll_following = true
		for x in line_count:
			label.append_bbcode('\n')
			yield(get_tree().create_timer(default_wait_time), "timeout")
	else:
		label.bbcode_text = ''
	if block.has('animation_out'): # split off from the other if-statement to allow
		yield(tween, "tween_completed") # both transition anims to happen simultaneously. i think
	
	if choices.get_child_count() > 0: # If has choices, remove them.
		for n in choices.get_children():
			choices.remove_child(n)
		choice_container.hide()
	if ENABLE_VOICE:
		voice_generator.stop_reading()
	
	if next_blockID is Array: # can set an array for 'next,' in which case one is selected randomly
		#print("randomizing next block from ", next_blockID)
		randomize()
		next_blockID = next_blockID[randi() % next_blockID.size()]
	if next_blockID == '': # proceed to next index rather than ending -Graham
		next_blockID = index + 1
		if next_blockID == dialogue.size(): #if there are no more indexes
			terminate()
			return
	if next_blockID is String and next_blockID == 'end':
		terminate()
		return

	prev_block = block # prev_block will be used to infer name, position, etc
	index = index_from_ID(next_blockID)
	
	update_dictionaries(dialogue[index])
	dialogue[index] = infer_missing(dialogue[index])
	emit_signal("block_complete", prev_block, dialogue[index])
	update_dialogue(dialogue[index])


func terminate(): # runs when 'end' block is reached.
	yield(get_tree(),"idle_frame")
	executing = true
	var lastblock = dialogue[index] if dialogue else null
	if ENABLE_VOICE:
		voice_generator.stop_reading()
	label.bbcode_text = ''
	reset_defaults()
	sprite_left.hide()
	sprite_right.hide()
	name_left.hide()
	name_right.hide()
	box.hide()
	hide()
	dialogue = []
	executing = false
	emit_signal("dialogue_complete", lastblock)


func update_variable(variables_dict, target_dict):
	var dictionary = game_data.get(target_dict)
	for key in variables_dict: # switched to a dictionary rather than 2D array
		if dictionary.has(key):
			dictionary[key] = variables_dict[key]


func check_answers(block: Dictionary): # for question blocks
	if alternate_choice_node_alignment: # put choice list on opposite side of portrait
		if block['position'] == 'right':
			hbox.move_child(choice_container, 0)
		else: # position == left:
			hbox.move_child(choice_container, hbox.get_child_count())
	
	var options = block['options']
	var conditions = block['conditions'] if block.has('conditions') else []
	var object = game_data
	if block.has('object'):
		object = get_node(block['object'])
		if !object:
			print('Error: unable to find object at path ', block['object'], ' in dialogue index ', index)
			return
	
	var choice_height
	executing = true
	for n in options.size():
		var include_option
		if conditions and n < conditions.size():
			if conditions[n] is bool or not conditions[n]: # empty string is okay
				include_option = true
			elif conditions[n] is String:
				include_option = yield(execute_expression(conditions[n], object), "completed")
				if not include_option is bool:
					print("invalid option condition ", include_option, " from expression ", conditions[n], " at dialogue index ", index)
					include_option = false
			else: 
				print("invalid option condition ", conditions[n], " at dialogue index ", index)
				include_option = false
		else: # no 'conditions' or 'conditions' too small
			include_option = true
				
		if include_option:
			var choice = CHOICE_SCENE.instance()
			choice.set_theme(choices.get_theme())
			if not choice_height or choice.rect_size.y < choice_height:
				choice_height = choice.rect_size.y
			
			if choice_text_alignment == 'right':
				choice.bbcode_text = '[right]' + options[n] + '[/right]'
			else:
				choice.bbcode_text = options[n]
			if n < block['next'].size():
				choice.next = block['next'][n]
			else:
				choice.next = ''
			choices.add_child(choice)
			choice.connect("focus_entered", self, "_choice_selected")
	executing = false
	
	var first = choices.get_child(0)
	var last = choices.get_child(choices.get_child_count() - 1)
	first.focus_neighbour_top = last.get_path()
	last.focus_neighbour_bottom = first.get_path()
	choice_container.show()
	choice_container.modulate = Color.transparent
	
	if CHOICE_LINES_ON_SCREEN: # resizing question box.
		choices.get_parent().rect_min_size.y = 0
		yield(get_tree(), "idle_frame")
		var height = clamp(choices.rect_size.y, 0, CHOICE_LINES_ON_SCREEN * choice_height)
		choices.get_parent().rect_min_size.y = height
		choices.get_parent().rect_size.y = 0
	else:
		choices.get_parent().scroll_vertical_enabled = false


func _choice_selected() -> void:
	for choice in choices.get_children():
		if choice.has_focus():
			next_blockID = choice.next


func _unhandled_key_input(event: InputEventKey) -> void:
	if not visible: return
	
	if label.bbcode_text: # manual scrolling
		if event.is_action_pressed(scroll_up_command):
			label.get_v_scroll().step = label.get_v_scroll().page / line_count
			label.get_v_scroll().ratio -= 0.05
			get_tree().set_input_as_handled()
			return
		if event.is_action_pressed(scroll_down_command):
			label.get_v_scroll().step = label.get_v_scroll().page / line_count
			label.get_v_scroll().ratio += 0.05
			get_tree().set_input_as_handled()
			return
		
	if choice_container.visible and choice_container.modulate != Color.transparent: # if choice menu is open
		var top_choice = choices.get_child(0)
		var bottom_choice = choices.get_child(choices.get_child_count() - 1)
		if choices.get_parent().visible and choices.get_focus_owner() == null:
			#e.g., if choices are visible but none are selected yet. this is necessary to begin focus
			if event.is_action_pressed('ui_up'):
				bottom_choice.grab_focus()
				get_tree().set_input_as_handled()
				return
			if event.is_action_pressed('ui_down'):
				top_choice.grab_focus()
				get_tree().set_input_as_handled()
				return
	
	if event.is_action_pressed(complete_command):
		get_tree().set_input_as_handled()
		executing = true
		yield(get_tree(), "idle_frame") # this prevents a very rare error where the user triggers complete_text before the dialogue loads.
		if not phrase_complete() and not disable_advance:
			complete_text()
			return
		executing = false
	
	if event.is_action_pressed(advance_command):
		get_tree().set_input_as_handled()
		if phrase_complete() and not disable_advance:
			next()
			return
	
	if input_blocking:
		get_tree().set_input_as_handled()


func _process(delta: float) -> void:
	# this is no longer handled by a timer node because that had the effect of placing
	# an upper limit on how quickly characters could be shown. now multiple
	# characters are shown at once if the timer is moving faster than _process.
	if timer > -60:
		timer -= delta
	if timer > 0 or timer <= -60: 
		return
	var show_characters = 1 + floor(-timer/wait_time)
	var printed_chars := ""
	
	for x in range(show_characters):
		var char_index = BB_text_index if autoscroll else label.visible_characters
		var continue_update = set_timer(char_index) and change_speed(char_index)
		if not continue_update: continue # either of the above functions can skip this loop by returning false.
		
		if phrase_complete():
			complete_text()
			return
		if not autoscroll:
			printed_chars += label.text[label.visible_characters]
			label.visible_characters += 1
		else: # autoscroll is complicated.
			var transplant = BB_text[BB_text_index]
			if transplant == '[':
				var end_bracket_find = BB_text.find(']', BB_text_index) # search for end bracket.
				if end_bracket_find == -1: # no end bracket at all.
					transplant = BB_text.substr(BB_text_index)
					BB_text_index = BB_text.length()
				else: 
					transplant = BB_text.substr(BB_text_index, end_bracket_find - BB_text_index)
					BB_text_index = end_bracket_find
			else: # character is not an end bracket.
				printed_chars += transplant
			label.bbcode_text += transplant # .append doesn't work with BB tags :(
			BB_text_index += 1
		
	# emit signals for purposes of portrait animations
	if printed_chars:
		emit_signal("characters_printed", printed_chars)


func phrase_complete() -> bool:
	if autoscroll:
		return BB_text_index >= BB_text.length() - 1
	else:
		if label.visible_characters == -1:
			return true
		return label.visible_characters >= label.text.length()


func complete_text(): #show complete text
	timer = -60.0 # otherwise _process() will call complete_text() again immediately.
	if not autoscroll:
		label.visible_characters = -1
	else:
		label.bbcode_text = BB_text
		BB_text_index = BB_text.length()
	emit_signal("printing_finished", dialogue[index])
	
	if dialogue[index].has('auto_advance'):
		var value = dialogue[index]['auto_advance'] 
		if value is float:
			executing = true
			yield(get_tree().create_timer(value), "timeout")
			executing = false
		next()
		return
	elif dialogue[index].has('options'):
		choice_container.modulate = Color.white
	elif enable_continue_indicator:
		animations.play('Continue_Indicator')
		continue_indicator.show()


func change_speed(char_index: int) -> bool:
	if not speed_changes.has(char_index):
		return true
	
	if not speed_changes[char_index] is int and speed_changes[char_index].empty(): # created by '-|'
		wait_time = default_wait_time
		pause_time = default_pause_time
		emit_signal("printing_speed_changed", 0)
		return true
		
	if speed_changes[char_index] == 0:
		# instantly insert all text before the next pause or speed change (without typewriter effect)
		var pause_indexes = speed_changes.keys() + pause_array
		pause_indexes.sort()
		var index_index = pause_indexes.find(char_index) #I'm sorry.
		while(index_index + 1 < pause_indexes.size() and \
				pause_indexes[index_index + 1] == char_index):
			pause_indexes.remove(index_index + 1)
		if index_index == pause_indexes.size() - 1:
			complete_text()
			return false
		var next_index = pause_indexes[index_index + 1]
		if autoscroll:
			BB_text_index = next_index
			var add_text = BB_text.substr(char_index, next_index - char_index)
			label.bbcode_text += add_text
		else:
			label.visible_characters = next_index
		timer += wait_time
		emit_signal("printing_speed_changed", 0)
		return false
		
	wait_time = 0.5 / pow(speed_changes[char_index], 1.8)
		# you can change the numbers here to change the available range of speeds if you want.
		# the left number is the minimum speed, and increasing the right number increases the maximum speed.
		# this setting yields a range between 0.5 (2 letters per second) and about 0.01 (~100 letters per second).
		# I decided to use an exponent so the higher speeds would make a more noticable difference.
	pause_time = 1.0 / (speed_changes[char_index])
	
	emit_signal("printing_speed_changed", speed_changes[char_index])
	return true


func set_timer(char_index:int) -> bool:
	if pause_array.has(char_index): # Check if current character should pause
		timer += pause_time
		pause_array.erase(char_index)
		return false

	if PAUSE_ON_PUNCTUATIONS:
		var current_char
		var next_char
		if autoscroll and char_index + 1 < BB_text.length():
			current_char = BB_text[char_index]
			next_char = BB_text[char_index + 1]
		if not autoscroll and char_index + 1 < label.text.length():
			current_char = label.text[char_index]
			next_char = label.text[char_index + 1]
		if current_char and PAUSE_ON_PUNCTUATIONS.has(current_char) and next_char == ' ':
			# pauses only on punctuation followed by space, to prevent '!!!' from pausing 3 times.
			timer += pause_time
		else: timer += wait_time
	else: timer += wait_time
	return true


func start_animation(direction, animation):
	var original_pos := Vector2.ZERO
	var offset_pos : Vector2 
	var sprite : TextureRect 
	
	if direction == 'left':
		sprite = sprite_left
		offset_pos = Vector2(-move_distance, 0)
	else:
		sprite = sprite_right
		offset_pos = Vector2(move_distance, 0)
	
	match animation:
		'fade_in':
			sprite.modulate = Color.transparent 
			# otherwise it won't be transparent until the next _process, creating a visible flicker
			tween.interpolate_property(sprite, 'modulate', Color.transparent, Color.white, 
					ease_in_speed/1.25, Tween.TRANS_QUAD, Tween.EASE_IN)
			tween.start()
		'fade_out':
			tween.interpolate_property(sprite, 'modulate', Color.white, Color.transparent, 
					ease_out_speed/1.25, Tween.TRANS_QUAD, Tween.EASE_OUT)
			tween.start()
			
		'move_in':
			sprite.modulate = Color.transparent 
			# otherwise it won't be transparent until the next _process, creating a visible flicker
			tween.interpolate_property(sprite, 'rect_position', offset_pos, original_pos, 
					ease_in_speed, Tween.TRANS_QUINT, Tween.EASE_IN)
			tween.interpolate_property(sprite, 'modulate', Color.transparent, Color.white, 
					ease_in_speed, Tween.TRANS_QUINT, Tween.EASE_IN)
			tween.start()
		'move_out':
			tween.interpolate_property(sprite, 'rect_position', original_pos, offset_pos, 
					ease_out_speed, Tween.TRANS_BACK, Tween.EASE_OUT)
			tween.interpolate_property(sprite, 'modulate', Color.white, Color.transparent,
					ease_out_speed, Tween.TRANS_QUINT, Tween.EASE_OUT)
			tween.start()
			
		'on':
			tween.interpolate_property(sprite, 'modulate', sprite.inactive_portrait, 
					sprite.active_portrait, ease_in_speed, Tween.TRANS_QUAD, Tween.EASE_IN)
			tween.start()
		'off':
			tween.interpolate_property(sprite, 'modulate', sprite.active_portrait, 
					sprite.inactive_portrait, ease_out_speed, Tween.TRANS_QUAD, Tween.EASE_OUT)
			tween.start()
		
		var shake_anim:
			sprite.shake(shake_anim)
