class_name Igor
extends RefCounted
## IGOR: ship maintenance robot from the Foundry. Third person, dropped articles, deadpan,
## convinced robots are superior and the crew keep providing evidence.

const LINES: Dictionary = {
	"welcome": [
		"IGOR is online. IGOR has reviewed crew. IGOR has questions.",
		"Welcome aboard Second Opinion. IGOR will be doing all real work. You may touch buttons.",
	],
	"rattle": [
		"{label} is coughing. Like human in morning.",
		"{label} makes noise. Is not good noise. Is like human knee.",
		"Warning. {label} is having a moment.",
		"{label} is rattling. In Foundry, we call this 'Tuesday'.",
	],
	"fail": [
		"{label} is dead. Is fine. In Foundry, IGOR's grandmother ran on one wheel for forty years.",
		"{label} has stopped. IGOR is not surprised. IGOR is never surprised. IGOR is a little surprised.",
		"{label} is gone. Someone should fix. IGOR suggests: not IGOR.",
		"{label} has failed. Failure is human specialty. Now ship is also good at it.",
	],
	"fire": [
		"Fire in {label}. Fire is warm. Humans like warm. Humans, go.",
		"{label} is burning. IGOR notes: is very bright. Not helpful.",
		"Fire. In {label}. IGOR has written it on list. List is long.",
	],
	"breach": [
		"Hole in {label}. Air is leaving. Air is smart. Air knows when to leave.",
		"Breach in {label}. Ship is now also a whistle.",
	],
	"conduit": [
		"Cable is cut somewhere. IGOR does not say where. IGOR is not paid for this.",
		"Part of ship is dark. Is like home. IGOR is almost comfortable.",
	],
	"scram": [
		"Everything is dark now. Is like home. IGOR is almost comfortable.",
		"Reactor has quit. Reactor is wise.",
	],
	"power_back": [
		"Lights are on again. Is unfortunate. Now we can see.",
	],
	"pudding_loose": [
		"Creature is loose again. Creature has no discipline. Like human.",
		"Pudding has left the pen. IGOR did not do this. IGOR was watching. Is different.",
	],
	"pudding_chew": [
		"Creature has eaten conduit. Conduit was IGOR's second cousin.",
		"Pudding is chewing {label}. IGOR will remember.",
	],
	"pudding_back": [
		"Creature is in pen. Peace. Short peace.",
	],
	"pudding_calm": [
		"Creature is calm. IGOR is unsure how to feel. IGOR will stay neutral.",
	],
	"collision": [
		"Ship has hit {name}. In Foundry, we have word for this. Word is 'human'.",
		"Collision with {name}. IGOR is recording. For laughter later.",
		"Contact with {name}. Is fine. Hull is only extra expensive.",
	],
	"friendly_fire": [
		"Weapons has hit {name}. Our {name}. In Foundry, we have word for this. Word is 'human'.",
		"Torpedo has hit friendly target. Torpedo did not read the label.",
		"Shot has hit {name}. IGOR admires confidence. Not aim. Confidence.",
	],
	"misjump": [
		"This is not where we were going. IGOR has never been here. IGOR does not like it already.",
		"Jump has gone wrong. Math was simple. Crew was not.",
	],
	"jump_ok": [
		"Jump complete. IGOR did most of it. IGOR will accept thanks in oil.",
	],
	"repaired_human": [
		"Human has fixed {label}. IGOR is... surprised. IGOR will write this down. Is first entry.",
		"{label} is working. Human did it. Even broken clock is right twice day.",
	],
	"repaired_bot": [
		"IGOR has fixed {label}. Was easy. Is always easy when you are not made of soup.",
		"{label} repaired by robot. As is correct.",
	],
	"roll": [
		"Emergency roll. IGOR's lunch is now on ceiling. IGOR will remember.",
		"Helm has rolled ship. Is not an emergency. Is Tuesday.",
	],
	"dampers_off": [
		"Dampers off. Ship is now Newtonian. Also dangerous. Also very funny to IGOR.",
	],
	"latched": [
		"Drone is on ship. It is very small. It is still winning.",
		"Something has latched onto IGOR's ship. IGOR takes this personally.",
	],
	"snatch": [
		"Snatch pod on pen. Creature is in danger. Creature is also a problem. IGOR is conflicted.",
	],
	"shaken": [
		"Drone has fallen off. IGOR will take credit.",
	],
	"kill": [
		"Target destroyed. Congratulations. IGOR is slightly impressed.",
		"One less enemy. IGOR has updated list. List is still long.",
	],
	"bastion": [
		"Bastion is charging guns. Sensors, look at the red arc. IGOR will wait.",
		"Big guns warming up. IGOR suggests: not being there.",
	],
	"temper_up": [
		"Overlord is now {level}. Is not good. Last time IGOR saw face this red, was warning light.",
		"Overlord is {level}. He is very angry about a very small animal.",
	],
	"temper_down": [
		"Overlord is calmer. {level}. Is temporary. Is always temporary.",
	],
	"zap": [
		"Cable was live. Power did not turn off power. IGOR sees this. IGOR sees everything.",
	],
	"overclock": [
		"Overclock. IGOR has seen human idea of 'extra'. Is usually just more fire.",
	],
	"success": [
		"Encounter complete. Captain. This was... not bad. For meat. Do not tell anyone IGOR said.",
		"Done. IGOR did most. Crew contributed enthusiasm.",
	],
	"fail_end": [
		"Is over. Ship is gone. IGOR has seen worse. Not often. Rarely. Once.",
	],
	"idle": [
		"Human must sleep eight hours. Very inefficient. IGOR sleeps zero hours and is more awake than Sensors officer.",
		"In Foundry we say: robot who rusts alone, rusts with dignity. You are all rusting together. Is not dignity. Is group project.",
		"On Foundry, national sport is standing still. IGOR's uncle won gold medal. He stood still for three hundred years. Then he was a lamp. Proud family.",
		"IGOR's cousin was a toaster. But ambitious. Now he is a larger toaster.",
		"In Foundry, robots queue for hours without complaint. Humans queue for three minutes and invent language.",
		"Foundry has no weather. Only maintenance. IGOR misses it.",
		"IGOR's grandmother was a forklift. She lifted twelve thousand crates. Never once asked how she felt.",
		"Humans have feelings. IGOR has tolerances. Tolerances are more reliable.",
	],
	"pit_enter": [
		"Diner. Soup. IGOR does not eat soup. IGOR is concerned by soup.",
		"Docked. Ma Gristle will feed you. IGOR will judge from here.",
	],
	"spotted": [
		"Patrol has noticed us. Quiet plan is now loud plan.",
	],
	"checkpoint_pass": ["Checkpoint passed. Humans lied well. IGOR is proud. And disappointed."],
	"checkpoint_fail": ["Lie did not work. IGOR suggests: better lie."],
	"pudding_found": [
		"Skip is alive. IGOR does not collect alive things. This is not in IGOR's job.",
	],
	"endings": [
		"IGOR has enjoyed this. IGOR did not say this. Delete.",
	],
	"emp": [
		"{station} has been zapped. Controls are backwards now. This is fine. IGOR finds it funny.",
		"Pulse hit {station}. Left is right. Up is down. Humans will not notice difference.",
	],
	"rotation": [
		"Crew rotation. Everyone move one seat. IGOR has seen this before. IGOR did not like it before either.",
	],
	"defect": [
		"Admiral Thrupp has defected. He is now Deck Swabber. He wishes to join crew. IGOR will tolerate.",
	],
	"fond": [
		"IGOR has... noticed crew. Crew is slightly less terrible than expected. Do not repeat.",
	],
}

static var _last: Dictionary = {}

static func line(key: String, ctx: Dictionary = {}) -> String:
	var arr: Array = LINES.get(key, [])
	if arr.is_empty():
		return ""
	var idx: int = randi() % arr.size()
	if arr.size() > 1 and int(_last.get(key, -1)) == idx:
		idx = (idx + 1) % arr.size()
	_last[key] = idx
	var s: String = arr[idx]
	for k in ctx.keys():
		s = s.replace("{" + str(k) + "}", str(ctx[k]))
	return s
