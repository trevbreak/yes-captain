class_name Igor
extends RefCounted
## IGOR: ship's robot from the Foundry. Third person, dropped articles, deadpan, convinced robots are
## superior. The crew keep providing evidence. (The joke is always on robots and humans, never a nationality.)

const LINES: Dictionary = {
	"welcome": [
		"IGOR is online. IGOR has reviewed crew. IGOR has questions.",
		"Welcome back, meat. Please touch only your own buttons.",
	],
	"broke": [
		"{name} is broken. In Foundry, IGOR's grandmother ran on one wheel for forty years.",
		"{name} has stopped. IGOR is not surprised. IGOR is a little surprised.",
		"{name} is broken. Engineer: this is what you are for.",
		"{name} has failed. Failure is human specialty. Now ship is also good at it.",
	],
	"overheat": [
		"{name} has cooked itself. Humans love full throttle. Engines do not.",
		"Engine is too hot. IGOR could fry egg on it. IGOR does not eat eggs.",
	],
	"jam": [
		"Gun is jammed. It was fired like it owed money.",
		"Gun has overheated. Short bursts, meat. Short. Bursts.",
	],
	"fire": [
		"Fire in {name}. Fire is warm. Humans like warm. Humans, go.",
		"{name} is burning. IGOR notes: is very bright. Not helpful.",
		"Fire. In {name}. Engineer: fire first, everything else later.",
	],
	"fire_out": ["Fire is out. Now {name} is only broken. Progress."],
	"repaired": [
		"{name} is fixed. IGOR would have been faster. IGOR has no hands. Still faster.",
		"{name} works again. Good human. Here is imaginary biscuit.",
		"Engineer has fixed {name}. IGOR will add this to very short list.",
	],
	"blackout": [
		"Everything is dark now. Is like home. IGOR is almost comfortable.",
		"Reactor has quit. Reactor is wise. Too many things asked for power at once.",
	],
	"power_back": ["Power is back. Please do not do that again."],
	"pudding_out": [
		"Pudding has escaped. Pudding is in walls. Pudding is eating cables. Pudding is living best life.",
		"Pudding is loose. Shields: shake the tin. Everyone: protect your wires.",
	],
	"pudding_chew": ["Pudding has eaten part of {name}. Pudding is not sorry."],
	"pudding_back": ["Pudding is back in pen. Pudding pretends nothing happened. Pudding is like captain."],
	"pudding_sad": ["Pudding is upset. Loud ship. Bad ship. Shields, pet the Pudding."],
	"bump": [
		"We have hit {name}. {name} did not move. {name} wins.",
		"Collision. Helm, the {name} was not a suggestion.",
	],
	"friendly_fire": [
		"You have shot {name}. {name} was not enemy. {name} is now enemy.",
		"Friendly fire. IGOR is writing this down in big letters.",
	],
	"roll": ["Barrel roll. IGOR's processor is now on ceiling.", "Wheee. IGOR did not say wheee."],
	"latched": ["Grabber is stuck to hull. It is chewing. Spin, shield or shoot."],
	"unlatched": ["Grabber is off. It is dizzy. IGOR is also dizzy. IGOR will not admit."],
	"kill": [
		"Target destroyed. IGOR would clap. IGOR has no hands. IGOR claps in heart.",
		"Is gone. Good shooting. For meat.",
	],
	"scanned": ["Sensors says: {name}. Now captain knows. Captain, say something."],
	"weak_found": ["Weak spot found: at the back. Like all bullies. Get behind it."],
	"torp_hit": ["Torpedo in the weak spot. Very satisfying. IGOR is recording."],
	"torp_bounce": ["Torpedo bounced. Only the back vent, meat. The BACK."],
	"hail_heard": ["Message received. Sensors: read it to captain. Out loud. With feeling."],
	"collected": ["{name} is aboard. Good catch. IGOR did not doubt. IGOR doubted a little."],
	"step_done": [
		"Done. Next.",
		"Is done. IGOR is moderately impressed. Do not get used to it.",
		"Good. Next thing.",
	],
	"mission_done": [
		"Mission complete. Ship is mostly in one piece. IGOR is proud. IGOR denies this.",
		"Is finished. IGOR has seen worse. Not often.",
	],
	"mission_failed": [
		"Is over. Ship is gone. IGOR has seen worse. Not often. Rarely. Once.",
		"We have failed. IGOR will tell other robots it was solar flare.",
	],
	"idle": [
		"IGOR is watching. IGOR is always watching.",
		"Captain: talking is free. Please use it.",
		"Fun fact: robots never shout. Robots do not need to. Humans, please shout.",
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
