class_name StoryText
extends RefCounted
# gdlint: disable=max-line-length
## All narrative text for the prototype in one place.
##
## Original writing for THE LAST SIGNAL (AVENOX Games). Keeping text here (instead of
## scattered through scenes) makes rewrites, proofreading and future localisation
## (e.g. Hindi via Godot's translation system) much easier.

const PLAYER_NAME := "Aarav"
const BROTHER_NAME := "Kabir"
const STATION_NAME := "Raatpur Junction"

const OBJECTIVES := {
	&"find_platform": "Find a way to Platform Three.",
	&"restore_power": "Restore emergency power. Find the Electrical Room.",
	&"breakers": "Close the three emergency breakers in the correct order.",
	&"go_platform": "Go to Platform Three.",
	&"find_kabir": "Find Kabir.",
	&"end": "",
}

## Readable documents: id -> {title, body}.
const DOCUMENTS := {
	&"station_notice":
	{
		"title": "NOTICE - RAATPUR JUNCTION",
		"body":
		"By order of the Divisional Office, Raatpur Junction is CLOSED to all passenger traffic until further notice, following flood damage to the signalling equipment.\n\nThe 23:58 night local will NOT stop at this station.\n\nStaff are reminded that the Platform 3 gate is electronically locked. In the event of a power failure, emergency power must be restored from the Electrical Room (Maintenance corridor, off the waiting hall) before the gate will open.\n\n- Station Master",
	},
	&"signal_poster":
	{
		"title": "KNOW YOUR SIGNALS",
		"body":
		"Every driver reads the signal ahead.\n\nRED - DANGER. The line ahead is blocked. Stop.\n\nYELLOW - CAUTION. The line is clearing. Proceed slowly and be ready to stop.\n\nGREEN - CLEAR. The line ahead is free. Proceed.\n\nWhen a blocked line clears, the signal always changes from danger, to caution, to clear. Never in any other order.\n\n- Railway Safety Week",
	},
	&"maintenance_log":
	{
		"title": "Maintenance Log - Electrical Room",
		"body":
		"Night of the storm. Main supply gone again. Emergency breakers tripped.\n\nREMINDER FOR NIGHT STAFF: the three emergency breakers feed the Platform 3 signal circuit. Close them in the same order the platform signal shows when a blocked line clears.\n\nAny other order overloads the panel and trips every breaker back to OFF.\n\nThe breaker lamps are colour coded. If you have forgotten your signals, read the safety poster in the waiting hall.\n\n- S. Dutta, Electrician (night shift)",
	},
	&"kabir_note":
	{
		"title": "A torn page in Kabir's handwriting",
		"body":
		"Aarav,\n\nIf you are reading this, you came. I knew you would.\n\nThis station is not empty. The announcer reads names from a list that nobody wrote. Mine was on it. I think yours is too.\n\nDon't wait for midnight in the dark. Get the power back on. The gate to Platform Three only opens when the lights do.\n\n- K.",
	},
}

## Short examine lines for story objects: id -> Array of [speaker, text].
const EXAMINE := {
	&"entrance_doors": [["", "Locked. Something heavy is holding them shut from outside."]],
	&"station_clock":
	[
		["", "The station clock has stopped at 11:57."],
		["Aarav", "The second hand keeps twitching... but it never moves."],
	],
	&"dead_board": [["", "The departure board is dark. No power."]],
	&"ticket_window": [["", "BOOKING OFFICE - CLOSED. A cold cup of chai still sits behind the glass."]],
	&"control_monitor_off": [["", "A signal control monitor. Dead, like everything else."]],
}

## Scripted story lines: id -> Array of [speaker, text].
const LINES := {
	&"intro":
	[
		["", "11:41 PM. Raatpur Junction. Monsoon rain."],
		["Aarav", "Kabir's message said Platform Three. Midnight. Forty-one days without a word... and then this."],
	],
	&"door_slam":
	[
		["", "The entrance doors slam shut behind you."],
		["Aarav", "Hey! Who's there? ...Locked. From the outside."],
	],
	&"announce_name":
	[
		[
			"Announcement",
			"Attention please. Passenger Aarav, please proceed to Platform Three. Your brother is waiting."
		],
		["Aarav", "How does it know my name?"],
	],
	&"gate_locked":
	[
		["", "PLATFORM 3. The gate's electronic lock is dead. No power."],
		[
			"Aarav",
			"No power, no gate. There must be a way to get the power back... maybe through that maintenance door."
		],
	],
	&"enter_electrical":
	[
		["Aarav", "Three breakers. Red, green, yellow. The log said the order matters."],
	],
	&"breaker_progress":
	[
		["", "The breaker clunks into place. Its lamp glows."],
	],
	&"breaker_mistake":
	[
		["", "The panel sparks! Every breaker trips back to OFF."],
	],
	&"breaker_hint":
	[
		[
			"Aarav",
			"The log said: the order a signal shows when a blocked line clears. The poster in the waiting hall explained the colours."
		],
	],
	&"breaker_hint_strong":
	[
		["Aarav", "Danger, caution, clear... Red, then yellow, then green."],
	],
	&"power_restored":
	[
		["", "Emergency power hums back to life."],
	],
	&"announce_power":
	[
		[
			"Announcement",
			"Attention please. Emergency power has been restored. The last train will depart from Platform Three at midnight."
		],
		["Announcement", "Passenger Aarav. Welcome back."],
		["Aarav", "Welcome... back? I've never been here before."],
	],
	&"apparition":
	[
		["Aarav", "Kabir...? KABIR!"],
	],
	&"reach_platform":
	[
		["", "Platform Three. Rain hammers the tin roof. The signal at the end of the line glows red."],
	],
	&"phone_found":
	[
		["", "Kabir's phone. The screen is cracked, but it's still on."],
		["", 'Last message sent: "Platform Three. Midnight."  -  11:57 PM, three years ago.'],
		["Aarav", "Three years...? That's impossible. It arrived tonight."],
	],
	&"midnight":
	[
		["Announcement", "The last train is now arriving on Platform Three."],
	],
}

## Text shown on the station monitors after the power returns.
const CONTROL_MONITOR_BOOT := "RAATPUR JN - SIGNAL CONTROL\n\nEMERGENCY POWER ...... ON\nPLATFORM 3 GATE ...... UNLOCKED\nPASSENGERS WAITING ... 2"
const CONTROL_MONITOR_FINAL := "WELCOME BACK, AARAV."
const DEPARTURE_BOARD_TEXT := "PLATFORM 3     LAST TRAIN     00:00     ON TIME"

const END_TITLE := "THE LAST SIGNAL"
const END_BODY := "End of prototype.\n\nThe signal turned green for the first time in three years.\nWhatever is arriving on Platform Three... is coming for both brothers.\n\nThank you for playing. The full story is in development."


static func get_objective(id: StringName) -> String:
	return OBJECTIVES.get(id, "")


static func get_document(id: StringName) -> Dictionary:
	return DOCUMENTS.get(id, {"title": "Missing document", "body": "No text found for '%s'." % id})


static func get_lines(id: StringName) -> Array:
	if LINES.has(id):
		return LINES[id]
	return EXAMINE.get(id, [])


## Queues a scripted set of lines as subtitles.
static func say_lines(id: StringName) -> void:
	for line: Array in get_lines(id):
		GameState.say(line[1], line[0])
