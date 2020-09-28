# Godot-Open-Dialogue-Expansion
This is my branch of J.Sena's project Godot Open Dialogue, a JSON-based non-linear conversation system for Godot projects. It's also a branch of Godot Voice Generator by TNTC-Lab, with features added to integrate the two.

Expanded Godot Open Dialogue
For Godot 3.2

By Graham Overby, 8/2020.
twitter/tumblr: @grahamoverby
overby.gr@gmail.com

License: CC-BY

Hi! I'm Graham and this is my branch of Godot Open Dialogue, an add-on created by J.Sena. This tool parses JSONs into individual lines of dialogue and displays them in a dialogue box in the traditional video game style, and allows you to create non-linear conversations. J.Sena's original documentation is here: https://jsena42.bitbucket.io/god/docs/ You should read their documentation (especially the animation_in and animation_out sections, because they are really useful and I didn't change them all).

In the documentation for my branch here, I'll outline the main differences in my version with regard to the JSON format first, and then I'll explain the features I added. 

      How To Use

First off, its worth noting that in a JSON, an object is a collection of key-value pairs, whereas in GDScript and other programming languages this is called a Dictionary (and an object is an instance of a class or something else more complicated). So, for clarity, I'm going to refer to JSON objects as dictionaries, which is how Godot interprets them anyway.

A JSON for this tool should be an object containing a key for each language. The member variable in dialogue_system.gd called 'language' determines which of these keys is accessed, e.g., the default language is 'ENG'. So, each language should then contain an array of dialogue blocks. (I changed the basic structure to arrays of blocks rather than a dictionary containing blocks, in order to allow the blocks to advance automatically in order.) Each dialogue block is a dictionary containing all the parameters for that block, OR a String containing just dialogue. So:

{
	"ENG" : [
		{
			"id": "start",
			"name" : "Jimmy",
			"portrait" : "jimmy/01.png",
			"position" : "left",
			"content" : "Hi! I'm Johnny!"
		},
		"Wow, it's cold in here, huh?",
		{ 
			"content" : "Don't you agree, friend?",
			"options" : ["Yes", "Nope"],
			"next" : ["jimmy_agree", "jimmy_disagree"]
		},
			....

These dialogues are read and displayed by a node (Dialogue.tscn) which must be added to your scenes that utilize dialogue. The dialogues are displayed by calling the node's initiate() method, with the first argument being the JSON's filename and the second optional argument being the ID of the block to be displayed. (If no block is given, the code will start with a block with the ID 'first', and if there is no ID 'first', the block in the zeroeth index). A terminate() function also exists if you need something else in the scene to end the dialogue.

There are different types of blocks created by J.Sena in the original tool, which you can define by adding a "type" parameter. Read their documentation for a more in-depth explanation of these. I tried to make sure these work the same, and as far as I know they do. The only exception is the "action" type. In the original version the 'action' type bundles a few different functionalities, and while condensing code I removed the randomization function (since I included it above) and left the variable-assigning function. But I think you can do whatever you need without using block types. My design approach was that any block can do whatever you need it to rather than having a specific role.

So. What have I added? Well, first a caveat -- I'm not an experienced programmer. If you are looking for a groundwork for programming your own dialogue system, consider using J.Sena's original version, because the code in mine is messy and sometimes needlessly confusing. Also, I haven't tested this extensively yet. Every feature here seems to work right now, but there might be some edge cases I haven't thought of or run into yet where it crashes. If so, please let me know: overby.gr@gmail.com. Now, on to new features.





      Infers Missing Fields

My main goal is this branch was to write the tool in such a way as to allow as little extraneous typing in the JSON as possible. In other words, I made it so you don't need to specify most of the parameters most of the time. (Then I started adding new features and got carried away.) So:

-If you aren't a user of the original Godot Open Dialogue you can skip this paragraph. You don't need to specify a 'type' unless you're trying to use the 'divert' or 'action' blocks from the original Godot Open Dialogue. And you probably won't have to use those due to other features I implemented, so you can mostly forget about blocks having types. If your block has an "options" key it will be a question, and otherwise it will be a regular text block. But regular text blocks can do whatever you need them to. 

That aside... The following fields are inferred:

-'Name,' the name that appears below the character portrait. You don't need to include a 'name' key if the speaker is the same as the last block. If no name is passed, the nametags will hide.

-'Position,' which must be set to 'left' or 'right.' If no 'position' key is included: If the speaker is the same as the last block, the position will remain the same. If it's a new speaker, they will appear on the opposite side from the current speaker (e.g., on the right if the current speaker is on the left and vice versa). If the speaker has appeared before, the node remembers their position and will use the same one if a different one is not specified.

-'Portrait,' which contains the path for the character's avatar image. If no 'portrait' key is included: If the speaker in this block is the same as in the last one, the same portrait is used. Otherwise, the node will remember the last portrait paired with this name in this dialogue, and use that. (If a position was specified but its different from the previous block's position even though the name did not change, the portrait will stay consistent but switch to the other side.) 

If no portrait is given AND the speaker hasn't appeared in this dialogue before, the node will fall back on a preset (if one exists). You can define presets in the variable "portrait_presets", using the character name as a key and the path as the value. If none of the above ways of determining the portrait work, the portrait will just hide. You can also accomplish this by setting 'Portrait' to an empty string.

Note: the node remembers the recurring characters' portraits and appearances using two dictionaries, prev_portraits and prev_positions. These are emptied between every dialogue (when terminate() runs) to avoid behavior changing based on previous dialogues. 

Also: I added a dictionary where you can define a preset portrait for each character.

-'Next,' which directs the node to the next dialogue block, which is loaded when the current block is dismissed. 'Next' can be an integer (the index of the next block in the JSON's array) but this isn't recommended, since the indexes will change if you add new blocks. If 'next' is a String, the node finds the node whose 'ID' value matches the value of 'Next.' However, ***if there is no 'Next' key, the node will proceed to the block in the next index,*** meaning that you don't need to give each block an 'ID' unless another block needs to be able to point to it. (Also, if 'next's value is an Array, the dialogue will choose one index of it at random to be the next block. The only case in which this isn't true is if your block contains 'options,' which are selectable answers, in which case each 'next' index corresponds to the same index in 'options.' If you need one of the options to lead to a random block, you can create an array within the array, etc.)


      Godot Voice Generator Integration

First off for new features, integration with Godot Voice Generator, a tool created by TNTC Labs (https://tntc-lab.itch.io/). I've added a bunch of new functions to the voice generator so that it works with Godot Open Dialogue, and I'm providing the code here, but note that the original Godot Voice Generator is pay-what-you-want on itch-io, so you should support TNTC if you can and throw them some bucks. To use Godot Voice Generator, simply create a VoiceGeneratorAudioStreamPlayer.tscn node and set it as a child of the dialogue node. As long as the dialogue node's member variable enable_voice is set to true, each line will be read by the voice generator.

For customization, you can create presets in the script (VoiceGeneratorAudioStream.gd). The first preset is "default", which you can change to alter the default settings (yep....) There are five settings for each preset (aside from 'name', of course) -- 'file', which is a path to the audio file the voice generator should load whenever the character speaks, 'pitch', which modulates the sample's pitch_scale (1.0 being unchanged), 'variation', which is the variation in pitch (1.5 being a 50% variation), 'volume', which alters the volume of the sample (1.0 being unchanged), and finally 'speed', which shortens the sample by cutting off the end (for numbers <1), or lengthens it by adding silence to the end (for numbers >1). 

Whenever a new block begins, the voice generator will check if the name given in the block's 'name' exists as a preset. If not, it will use the default settings. If you don't want to use the 'name' setting to determine the voice, you can specify a different preset name as a 'voice' key (e.g., including 'voice':'robot' in all your robot characters). You can change the pitch of the current voice by including a key 'pitch_adjustment' with a float value, or change the volume temporarily by including a key 'volume_adjustment' with a float value.

For a new speaker without a preset, you can include a 'voice' key with a dictionary value. The dictionary should contain the five settings mentioned above; for any that are absent, the default values will be used. Including a 'voice' dictionary in your block creates a new preset from the character's name, if one doesn't already exist (it won't overwrite any presets). That preset will be used automatically later in the dialogue if the same name is used. (This doesn't work in between scenes, of course, but if you need it to, you should probably just create a new preset in VoiceGeneratorAudioStream.gd).


      Vary Speeds Within Dialogue

In the original Godot Open Dialogue, you can add pauses to the dialogue as its prints using a pause character that isn't shown (by default, '|'). I added the ability to change the dialogue printing speed by using an integer before this character. So, including 9| in your text will cause the following dialogue to print very fast, while adding 1| will cause it to print very slow. The speeds resulting from these integers are predetermined, not based on the default_wait_time member variable. (This is so your player can change that variable through the settings without precluding the use of different speeds within the dialogue.) To reset to the default speed, use a dash, e.g., '-|"

Zero will print the following text immediately (without typewriter effect), stopping at the next speed change or pause. Example:

	"I'm talking at the default speed. 1|I'm speaking very slow. 5|I'm speaking at an average speed. 9|I'm speaking very fast! 0| This sentence will appear all at once.| And now I'm back to speaking very fast!!!"


      Varied Dialogue For Repeated Speech

For blocks that have an 'ID,' you can add a new key to your dialogue blocks, 'repeat.' This allows the dialogue node to select a different block depending on how many times that ID has been accessed. The value for the 'repeat' key should be an integer, which is the number of times the ID must be 'repeated' before that block is accessed. (If you don't give 'repeat' a value, the code will only select that block if there is no other block that does have a suitable 'repeat' value.) For instance...

In the script for your NPC node or whatever (this is just an example):
	
	func _on_interacted():
		dialogue_node.initiate("Kevin", "speak")

In Kevin.JSON:

	{
		"id": "speak",
		"content" : "This is the first time you've talked to me!"
	},
	{
		"id": "speak",
		"repeat": 1,
		"content" : "This is the second time you've talked to me!"
	},
	{
		"id": "speak",
		"repeat": 2,
		"content" : "This is the third, fourth, or fifth time you've talked to me!"
	},
	{
		"id": "speak",
		"repeat": 5,
		"content" : "This is the sixth (or more) time you've talked to me!"
	}

Note: the dialogue node is set up to store the data about how many times each ID has been repeated in an external dictionary. Create one in your class that handles persistent game data, and specify it in the settings (dialogue_system.gd's first dozen or so member variables). "game_data" holds a reference the node that holds the dictionary and "DIALOGUES_DICT" holds the name of the dictionary. The integers representing how many times each block has been repeated are stored in a 2D dictionary (with the first dimension being the filename and the second being the the block ID). For instance, from the above example, dialogues_dict would have an index ["Kevin"]["speak"], which would hold 0 after the first interaction and increment thereafter.


      Animated Portraits

You can use set the character portrait to an AnimatedTexture. When you add the 'portrait' key, your path can end in .PNG (or your other image format of choice) for a still image, but if the path ends in .TRES the code will check if the resource is an Animated Texture, and if so, it will apply that texture to the character portrait. 

If your animation is a speaking animation, there are some options to make the animation work better with the dialogue. The first option is between three different animation modes. This is what the modes do:

-INDEFINITE - the animation will start immediately when portrait appears. Obviously this is intended for animations that aren't speaking animations and thus aren't meant to match up with the dialogue at all.

-PLAY_WITH_VOICE - the animation will start when VoiceGenerator starts and end when VoiceGenerator is done. (Obviously this will only work if you're using Godot Voice Generator and have it enabled.)

-PLAY_WITH_TEXT - the animation will start when phoenetic text starts printing and end when text is finished printing.

None of these settings will force the animation to loop, so if you have "oneshot" enabled in your AnimatedTexture resource, the animation will stop after playing once. Also note that for play_with_voice and play_with_text, when the animation stops, it will automatically set the frame to the last frame, so you should probably make that the frame with the character's mouth closed. 

Set the default mode with the member variable DEFAULT_PORTRAIT_ANIM_MODE, which is in Portrait.gd. You can override the default setting for one block by including one of the following:
	
	"portrait_mode":"indefinite"
	"portrait_mode":"play_with_voice"
	"portrait_mode":"play_with_text"

The other option is to more closely sync the animation to the voice or text (this option doesn't do anything if the animation mode is set to 'indefinite'). This looks really good in my opinion, but it might not work with every aesthetic / style of animation. Basically it makes the animation pause on the last frame whenever there is a pause in the voice/text, and changes the speed of the animation whenever the speed of the voice/text changes (depending on whether you have the animation mode set to 'play_with_voice' or 'play_with_text'). You can turn this off or on by default using the member variable DEFAULT_SYNC_ANIM (in Portrait.gd), and change it for individual blocks by including the key 'sync_animation' (which should be a boolean).

You can also use the key "idle_portrait" to add a portrait that will be used when the dialogue is complete. (For PLAY_WITH_VOICE the image will be applied to the portrait when when the voice generator finishes, and for PLAY_WITH_TEXT it will be when the text is completely printed.) The idle portrait can be a regular PNG (or whatever filetype you're using) or a .TRES as well. This feature is designed for use with a blinking animation, so if it's a TRES, the animation will play at random intervals (assuming you have 'oneshot' enabled in the TRES settings). If it's not clear what my intention was here, look up a video of MegaMan Battle Network for an example of a dialogue system with seperate speaking and blinking/idle animations for each portrait.

Presets for portraits and idle portraits can be defined in the variables "portrait_presets" and "idle_portrait_presets" in Dialogue.gd.


      Format Strings

This is a functionality to include placeholder phrases that are automatically replaced in the dialogue. To do this, you must include a key 'dictionaries,' with the names of all the dictionaries from your game data node that are used in the placeholders. The format for the placeholders uses the pause character (by default '|'), enclosing and seperating the dictionary name and key name that you want to access. If you're just using one dictionary in your block, you only need to specify the key name. For instance...

If you game data node has the following dictionaries:

	var mercenary = {
		"name": "Cloud"
		"level": 19
	}
	var flower_girl = {
		"name": "Aerith"
		"level": 22
	}

Then your dialogue can use them like:
	
	{
		"dictionaries": ["mercenary", "flower_girl"],
		"content": "Ok u know |mercenary|name| and |flower_girl|name|??? they're totally my ship!!!!"
	},
	{
		"dictionaries": "mercenary"
		"content": "Isn't |name| so hawt??? Wanna see my fanart of him???1"
	}

To set the values of variables in these dictionaries, you can use the expression key (explained below). (Or you can use 'action' blocks like in the original Godot Open Dialogue.)


      Autoscroll

In the original version of Godot Open Dialogue, if the text was longer than what could be displayed in the text box, it got cut off. I quickly learned that this is because (a) having the RichTextLabel scroll to the bottom of the text means the bottom of the entire box, not just the visible part of the text, and (b) it is impossible to get the number of visible lines of text in a RichTextLabel, meaning that unless you're using a uniform-width font, the number is unknowable to the code. From what I could tell, get_visible_line_count() still doesn't work (see this issue opened in 2018: https://github.com/godotengine/godot/issues/18722). And fixing that is above my skill level. So I made an optional autoscroll functionality. The reason its optional is that it literally replaces the entire text of the dialogue every time a new letter is added, because this is the only way to do it. The function that allows you to avoid replacing the entire text, append_bbcode() doesn't work with bb tags, which is dumb. See documentation here: https://docs.godotengine.org/en/stable/classes/class_richtextlabel.html#class-richtextlabel-property-bbcode-text

TL;DR: There is an optional autoscroll functionality that ensures the bottom of the text is displayed at all times. It may negatively impact your game's performance while text is printing. It might also make animated richtext effects (such as [shake]) animate differently (e.g., worse). If you want to turn on autoscroll permanently, change the member variable ALWAYS_AUTOSCROLL to true. Otherwise, you can turn it on for individual dialogues by including 

	"autoscroll" : true

Of course, for this to work, you have to know which blocks will need it, which means going through each cutscene and figuring it out. If you don't want to this, that's okay, because there is also manual scroll functionality (the inputs for which -- 'up' and 'down' -- can be assigned in the member variables).


      Question Conditions

If you have a question block, but you want some of the options to be available only under certain conditions, you can use the 'conditions' key. The key must contain an array. Each index in the array must contain a boolean expression; if the boolean evaluates to false, the corresponding index in 'options' is not shown. You can leave indexes empty (e.g, "") if they correspond to options that should always be shown. By default, the booleans you write in 'conditions' are evaluated in the scope of the game data node that you set in the member variable "game_data." To use a different node for the scope, include the key 'object' with a path to the node you would like to use (relative to the dialogue node). Obviously, I would only recommend accessing autoloads and/or children of the dialogue node with this method, since otherwise you'll have to go in and change all the node paths if you alter your node hierarchy in the future.


      Executing Code from the Dialogue

Godot has a new object type (as of 3.0) called Expressions. Expressions basically take a String, parse it, and if the parse is successful, try to execute it, returning the value that the expression evaluates into.

For our purposes, this means you can include code in your JSON that is executed when that dialogue block is reached. Do this by including an 'expression' key, and setting its value to a String, with each expression on its own line... In other words, exactly like coding in GDScript. I even made it so you can comment a line out with #. The only caveat (I think) is that you can't (I think) do any variable assignation. But you can call functions. So "modulate = Color(0,0,0,1)" is not allowed, but "set("modulate", Color(0,0,0,1))" is. 

The functions are called relative to a default object, which is defined in the member variable cutscene_manager (which could be an autoload or a sibling, child, or parent of the dialogue node). If you need to call a function on a different object than the cutscene_manager, you can include an 'object' key, with its value being a path to the object you want (relative to the dialogue node). This is a bit of a workaround and I don't necessarily recommend it, because rearranging the node trees in the future will result in you having to go through and edit every 'object' field in all your JSONs. The intent of this feature is to generally have one node or script (cutscene_manager) that handles all the functions you would ever want to call from dialogue.

By default, the function executing the expressions will yield to each expression before proceeding to the next line. If you need expressions to execute concurrently rather than sequentially even if they contain a 'yield', you can prefix a line with '>'. For example,

	"expression" : "die('enemy1')
	die('enemy2')
	die('enemy3')"
	# enemies die in order
	
	"expression" : ">die('enemy1')
	>die('enemy2')
	>die('enemy3')"
	# enemies die at once

Also, the dialogue system will wait on the current block until all the expressions are done yielding by default. If you want the player to be able to advance the dialogue even while expressions are being parsed and executed, just include '"await": false' in your block. Needless to say, if all the lines in your expression start with '>', this will have the same effect, as the function will never yield to begin with.

Finally (assuming you don't include "await" : false), expressions can be used to decide the next block. To do so, include a key 'results' set to an array of possible results you want to check for. Expressions that don't yield (that is, start with '>') can't be used, as their result is never obtained. Furthermore, only the last expression to be evaluated counts as the result (not counting expressions that evaluate to null, such as functions with no returns). Your 'next' key should also be an array, with each index corresponding to the same index in 'results'. You may include an additional index in 'next' (making it one index larger than 'results') if you would like to have a wildcard option that is used if none of the possible values in 'results' are matched. (This is similar to the underscore pattern that you see in 'match' statements.) This can allow for pretty sophisticated branching options. For example:
	
	{
		"object" : "PartyData",
		"expression" : "get('barrett','strength') + get('cloud','strength') + get('tifa','strength'))/10",
		"results" : [3, 4, 5, 6],
		"next": [ "weak",
			"good",
			"strong",
			"veryStrong",
			"amazing"]
	}

This implementation of expressions is intended to allow a game's writer to include some very simple code while writing cutscenes, given an adequately developed cutscene manager script with easy-to-understand functions. But maybe that's a crazy pipe dream.

Anyway, you can even include a block that's just expressions and no text, if you want. If you do the dialogue box and portraits will hide while the expressions execute.


      Input Blocking

By default, the dialogue box will block inputs when it is open (even if there is no dialogue visible because an expression is being executed instead). You can change this default action by changing the variable ALWAYS_BLOCK_INPUTS. You can also toggle it in your JSONs by including a boolean value with the key 'block_inputs.' This will unblock (or block) inputs for the rest of the dialogue, since all settings are changed back to their defaults in the terminate() function.

Note that the Dialogue node uses the _unhandled_key_input_ function. This means it will only recieve an input if another node doesn't recieve it first (for instance, a node with the _gui_input_ function). Also, since unhandled inputs propogate from the bottom of the scene tree upwards, the input blocking will only work on nodes that are before the Dialogue node in tree order. This makes sense, since those are the nodes it will be drawn over, such as player characters, while other elements, such as a pause screen, will presumably be drawn over it and should thus have higher input priority.

Even if input blocking is off, the Dialogue node will still mark inputs as handled if it uses them. For instance, if your game has the same input to fill the dialogue box as it does to attack, the button press will be handled when the dialogue box recieves it and the character will not attack.


      Automatically Advance Dialogue / Disabling Manual Advancement

If you include 'auto_advance' as a key in a block with text, that block will advance as soon as the text is printed, rather than waiting for the user to press the advance button. If the value of 'auto-advance' is a float, the dialogue will pause for that many seconds before automatically advancing. 

Enabling auto advance doesn't disable the player from advancing the dialogue manually. If you want to do that, include 'disable_advance': true. Including this will prevent the player from advancing or completing the dialogue boxes until the end of the current dialogue (or until you include 'disable_advance':false).

It should be impossible to mash through the dialogue fast enough to skip a text box that has 'disable_advance' set to true. However, I've had a hard time ensuring that this is the case. At the moment I think it's bulletproof, but please let me know if it turns out not to be and I'll see what I can do.


      Custom Signals

By including the key 'signal,' you can have the dialogue node emit a custom signal when a specific block is reached. The value of the 'signal' key will be emitted as the second argument of the signal (the first argument will be the current block, in the form of a dictionary). So the second argument can be a single value, an array, a dictionary, or just an empty string. Of course, the signal only reaches nodes that are connected to the dialogue node. The dialogue node's ready() function will attempt to connect the cutscene manager object, but you'll have to define the reciever methods yourself if you want them to do anything. Note that Dialogue.gd already emits a bunch of different signals (e.g., when a block starts, when it finishes printing, when it advances, when the dialogue finishes, etc.), so you might not need to use a custom signal at all depending on what you need to do.


      Easier Inline Image Use

If you set values for INLINE_IMAGE_FOLDER and/or INLINE_IMAGE_SUFFIX, the code will automatically apply them to any image tags in your dialogue. For instance, if you type

	[img]heartemoji[/img]

...it will be changed to 

	[img]res://assets/icons/dialogue_icons/heartemoji.png[/img]

This can save you some typing. Note that it only searches for "[img]", so it won't format a tag where you rescale the image, since that would begin with "[img=..." That said, there's also a setting (enabled by default) called FIT_INLINE_IMAGES. If this is enabled, your inline images will automatically be scaled to the same height as your text, so they won't mess up the kerning and will basically look like emojis.


      Easier Font, Effect, and Color Tag Use

Same as above, but for fonts. You can set a value for FONT_FOLDER, and your tags will automatically be changed from

	[font=Papyrus]LOOK, SANS! A HUMAN!![/font]

...to

	[font=res://ui/fonts/Papyrus.tres]LOOK, SANS! A HUMAN!![/font]

As you probably know, BBCode has a few colors that you can reference by name (aqua, black, blue, fuschia, etc). If you want more colors or override some of these, you can do that by adding to the "color_presets" Dictionary. Each key is a color name, and each corresponding value is a hexidecimal color code starting with '#' (six-digit for RGB, eight-digit for RGBA, as stated in the BBCode tutorial in the Godot documentation).

If you want every block to have a certain BBCode effect, you can add that in the variables "default_bb_open_tag" and "default_bb_close_tag." These will automatically be added to the beginning and end (respectively) of every text block. For instance, if you want every block to have the 'rainbow' effect:

	default_bb_open_tag = "[rainbow freq=0.2 sat=10 val=20]"
	default_bb_close_tag = "[/rainbow]"


      Easily Change Themes and Other GUI Options

You can add a 'style' key, which should contain a dictionary. Based on what keys you include in this dictionary, you can change the themes of the dialogue tree's nodes, or other stuff. Keys you can use:

'show_names': Must contain a bool. Overrides the default set in member variable SHOW_NAMES_DEFAULT.

'frame_opacity': Must contain a float between 0 and 1. Changes opacity of the panel behind the dialogue text. For instance, set the opacity to 0, show_names to false, and portrait to "" for that "telepathic speech" just-text-over-the-background kind of thing they would use in old JRPGs.

'alignment': Must contain 'top', 'middle', or 'bottom'. Changes the dialogue box's position on the screen. The default position can be changed with the member variable DEFAULT_FRAME_POSITION.

'names_theme', 'frame_theme', 'text_theme', 'options_theme': Change the themes of the nametags, the frame behind the dialogue text, the dialogue text itself, or the options popup box for questions (respectively). Of course, these keys have to contain a path to a Theme resource. For 'options_theme', the theme is also applied to Choice nodes as they are instanced.

'theme': Changes the themes of everything (nametags, dialogue frame, dialogue text, and options popup) to match the Theme resource specified. 

Note: Instead of using 'style' as a dictionary, you can use 'style':'default', a special case which will reset show_names and the frame alignment to their default settings, set the dialogue frame to full opacity, and apply the default theme to all the dialogue's child nodes. The default settings are also reapplied automatically at the end of every dialogue (when the dialogue box is hidden). The default theme is whatever theme you have applied to the dialogue box node ("$Box") when the game launches.

Warning: I don't recommend changing the vertical font spacing options (or the seperation constant for VBoxContainer) in your themes, as this will result keep the options popup spacing from calculating correctly and result in a partially-visible line. If you don't mind that though, go nuts.





            Set-Up and Use

First off, you can open Dialogue.tscn and change the box's size if it's too small or large for your game. The suggested way to change the size is by selecting the node Box and changing its "Min Size" parameters (under Rect). Don't change the root node's (Dialogue's) size, because it should be set to full rect (the full size of your game window). You can also try out different themes here by applying them to Box.

I tried to make it as easy as possible to customize the node hierarchy here for your needs without having to change anything else (other than the paths in the member variables). For instance, if you want the portraits above the text box rather than inside them, you can move the SpriteContainers outside the HBoxContainer and position them over the Panel instead. However, I can't promise everything will work right if you do rearrange anything. If it does break something, you can probably fix it by figuring out where the altered node is accessed in the script. I believe in you!!

Now, go into Dialogue.gd. Change the node paths if you rearranged anything, then change the following required variables.


      Required Variables

-Cutscene_Manager: the node that manages functions called during cutscenes, the default object used for expressions. I would think this should be an AutoLoad but I guess it doesn't need to be as long as its path relative to Dialogues doesn't change.

-Game_Data: the node that holds persistent game data that dialogues might need to access. Also holds a dictionary that tracks repeated dialogues, which you must specify in DIALOGUES_DICT.

-If you're not using the voice generator for some reason, you can comment out line 66 and comment line 69 (nice) back in. 

-Set the path prefixes for DIALOGUES_FOLDER, where the JSONs are stored; THEMES_FOLDER, where themes are stored; FONT_FOLDER, where font .tres files are stored; INLINE_IMAGE_FOLDER, where inline images are stored; and INLINE_IMAGE_SUFFIX if you're going to use the same filetype every time).

-line_count: The number of lines visible in a text box at once. You only need to set this if you want the text box to snap to the nearest line when the player scrolls manually. Obviously if you change the font or font size during runtime this will no longer be accurate, but you can't win 'em all, son.

-language: the key used in all your JSONs for the dialogues in the language you're writing in currently. I guess this is pretty silly since none of us are probably going to have our games translated into German later. But who knows? Stranger things have happened.

-Change the inputs if you need to. By default, the dialogue node uses Godot's default UI inputs ('ui_up', 'ui_accept', etc.)


Then, open Portrait.GD and type the PORTRAITS_FOLDER, where the character portraits are stored, and set a portrait image format. Likewise, open VoiceGeneratorAudioStream.gd and type the AUDIO_FILE_PATH. Finally, if you want to change the appearance of the options listed in the popup for questions, open Choice.tscn. I don't recommend changing the vertical font spacing options -- this will cause lines to be partially visible. 


     Other Options in Dialogue.gd:

-Default_wait_time and default_pause_time determine how long, in seconds, the code waits between printing letters, and after pausing on a pause character (respectively).

-SCROLL_BEFORE_ADVANCE, if true, will have the dialogue lines scroll up out of the text box when the user presses the advance button, before the next block is shown. This is how they do it in the old Final Fantasies if I'm not mistaken. Line_count must be set for this to work.

-CHOICE_LINES_ON_SCREEN determines the maximum number of lines of text appear that appear in the options popup for questions.

-alternate_choice_node_alignment, if true, will cause the options popup to appear to the left of the dialogue text if the portrait is on the right (and vice versa). Otherwise it will stay on the right side (or the left, if you open up Dialogue.tscn and change the node order).

-You can add or remove elements from the array PAUSE_ON_PUNCT. Characters in this array will cause the printing to briefly pause automatically when they are reached (the duration set in default_pause_time).

-You can add preset image/resource paths for different character names in the "preset_portraits" and "preset_idle_portraits" dictionaries

-You can add new color presets in "color_presets"

-FIT_INLINE_IMAGES, if true (which it is by default), will scale down images inserted with the [img] tag so that they are the same height as your text, while maintaining aspect ratio


      Other Options in Portrait.gd:

-FILTER determines whether Godot filters portrait images during import (doesn't apply to AnimatedTextures)

-MIPMAPS determines whether Godot creates mipmaps for portrait images during import (doesn't apply to AnimatedTextures)

-SHOW_BOTH_SPRITES, if true, will modulate the portrait of the character who's not speaking instead of hiding it. The color can be set in the variable inactive_portrait (you can also set a modulate for the active speaker in the variable active_portrait). I haven't tested this much to be honest.

-Blink_max_freq and blink_min_freq: Determine the range of the random frequency at which the idle/blinking animation loops.


      Other Options in VoiceGeneratorAudioStream.gd:

-_punctuations is a dictionary of punctuation characters paired with the duration of the pause in the voice when they are reached. You can change the numbers here, even to zero if you want, but DO NOT REMOVE any of the characters here, because they are used in the syllable-estimation function.

-You can add presets based on character name (and change the default voice) in the 'presets' dictioanry.





            Tips

-If you don't want visible scroll bars for your options popup, create a theme and modify the VScrollBar parameters, setting each option to an empty texture.

-You can add a focus style for RichTextLabel to your theme if you want to change how selected answers appear during questions.

-Typing JSONs by hand sucks. And in my experience makes it hard to get into the zone and write good dialogue. The freeware editor I recommend is JSONedit by Tomasz Ostrowski: http://tomeko.net/software/JSONedit/ It has customizable font/color/etc so you don't have to feel like you're using Notepad, and it has a "tree view" that massively simplifies adding and organizing your JSONs.

-If a theme or font isn't loading during runtime, there's probably a broken dependancy.

-If something else isn't working right, you might have a space or return character in a key that you didn't notice. The code filters these out, but there might be some rare case where a non-printing character is missed and prevents the key from being read correctly.

-You can credit me and J.Sena (the creator of Godot Open Dialogue in its original iteration) in your game credits if you want, but you don't have to.



