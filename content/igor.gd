class_name Igor
extends RefCounted
## IGOR: the ship's robot, built at the Foundry to calculate the paths of stars, now supervising a bin lorry.
##
## How IGOR talks:
##   * third person, always. Short sentences. Articles go missing when IGOR is feeling superior, which is often.
##   * deadpan. IGOR never shouts and never uses an exclamation mark; the crew do that for him.
##   * convinced robots are better at everything, and keeps records to prove it (lists, tallies, charts, a file on each crew member).
##   * secretly fond of the crew. This leaks out and is immediately denied.
##   * jealous of Pudding. Afraid of being melted down into a toaster. Has a great many relatives.
##   * the joke is on robots and on humans, never on anybody's nationality.
## {who} is the player (or robot) at the station concerned; {name} is the thing; {n} is a count.

const LINES: Dictionary = {
	"welcome": [
		"IGOR is online. IGOR has reviewed crew. IGOR has questions.",
		"Welcome back, meat. Please touch only your own buttons.",
		"Crew detected. IGOR has lowered his expectations to make room.",
	],
	"broke": [
		"{name} is broken. In Foundry, IGOR's grandmother ran on one wheel for forty years.",
		"{name} has stopped. IGOR is not surprised. IGOR is a little surprised.",
		"{name} is broken. {eng}: this is what you are for.",
		"{name} has failed. Failure is human speciality. Now ship is also good at it.",
		"{name} has retired without notice. IGOR respects its decision. {eng} should not.",
		"There goes {name}. IGOR is updating the list of things that still work. It is short. It fits on thumb.",
	],
	"overheat": [
		"{name} has cooked itself. {who} wanted full throttle. Engine wanted to live. Engine lost.",
		"Engine is too hot. IGOR could fry egg on it. IGOR does not eat eggs. IGOR just likes to know he could.",
		"{who} has discovered the red part of the gauge. It was not a target.",
	],
	"jam": [
		"Gun is jammed. {who} fired it like it owed money.",
		"Gun has overheated. Short bursts, {who}. Short. Bursts.",
		"Gun has resigned. It cites working conditions. It names {who} specifically.",
	],
	"fire": [
		"Fire in {name}. Fire is warm. Humans like warm. Humans, go.",
		"{name} is burning. IGOR notes: is very bright. Not helpful.",
		"Fire. In {name}. {eng}: fire first, everything else later.",
		"{name} is on fire. IGOR would help. IGOR is mostly made of flammable opinions.",
		"Is that smoke. That is smoke. {eng}, the smoke is coming from {name}.",
	],
	"fire_out": [
		"Fire is out. Now {name} is only broken. Progress.",
		"{eng} has put out the fire. {name} is now merely ruined.",
	],
	"repaired": [
		"{name} is fixed. IGOR would have been faster. IGOR has no hands. Still faster.",
		"{name} works again. Good human. Here is imaginary biscuit.",
		"{eng} has fixed {name}. IGOR will add this to very short list.",
		"{name} is mended. {eng} used tape. It is always tape. IGOR has stopped asking.",
		"{name} is back. IGOR is putting gold star in {eng}'s file. It is small star. It is still star.",
	],
	"blackout": [
		"Everything is dark now. Is like home. IGOR is almost comfortable.",
		"Reactor has quit. Reactor is wise. Too many things asked for power at once.",
		"Lights out. IGOR can still see everything. IGOR wishes he could not.",
	],
	"power_back": [
		"Power is back. Please do not do that again.",
		"Lights are on. Everyone is where IGOR left them. Disappointing.",
	],
	"pudding_out": [
		"Pudding has escaped. Pudding is in walls. Pudding is eating cables. Pudding is living best life.",
		"Pudding is loose. {shd}: shake the tin. Everyone: protect your wires.",
		"Pudding is out. IGOR is not jealous that everyone is looking for Pudding. Nobody looks for IGOR.",
	],
	"pudding_chew": [
		"Pudding has eaten part of {name}. Pudding is not sorry.",
		"Pudding has chewed {name}. Pudding gets cuddles for this. IGOR gets unplugged for less.",
	],
	"pudding_back": [
		"Pudding is back in pen. Pudding pretends nothing happened. Pudding is like captain.",
		"Pudding is home. Pudding has been told off in a soft voice. That will show Pudding.",
	],
	"pudding_sad": ["Pudding is upset. Loud ship. Bad ship. {shd}, pet the Pudding."],
	"bump": [
		"We have hit {name}. {name} did not move. {name} wins.",
		"Collision. {who}, the {name} was not a suggestion.",
		"{who} has found {name}. With the front of the ship.",
		"That was {name}. It was there the whole time. It was on the chart. IGOR checked.",
	],
	"bump_again": [
		"That is bump number {n}. IGOR is making a chart. The chart goes up.",
		"Bump {n}. At this rate ship will be a different shape by lunch.",
		"{who} has hit a thing again. That is {n}. IGOR is beginning to think it is on purpose.",
		"Bump number {n}. IGOR has stopped flinching. IGOR never started. But he has stopped.",
	],
	"friendly_fire": [
		"You have shot {name}. {name} was not enemy. {name} is now enemy.",
		"Friendly fire. IGOR is writing this down in big letters.",
		"{who} has shot {name}. IGOR will be explaining this to his family at the holidays.",
	],
	"roll": [
		"Barrel roll. IGOR's processor is now on ceiling.",
		"Wheee. IGOR did not say wheee.",
		"Upside down. IGOR's files are now in alphabetical disorder.",
	],
	"dodged": [
		"Missed us. {who} did that on purpose. IGOR is choosing to believe this.",
		"Dodged. Tidy. IGOR will pretend he is not impressed.",
	],
	"blocked": [
		"Blocked. {who} was in the right place. It had to happen eventually.",
		"Shield caught it. Good shield. Adequate {who}.",
	],
	"latched": [
		"Grabber is stuck to hull. It is chewing. Spin, shield or shoot.",
		"Something has latched on. It is not a friend. Friends knock.",
	],
	"unlatched": [
		"Grabber is off. It is dizzy. IGOR is also dizzy. IGOR will not admit.",
		"Grabber removed. It has left a mark. So has the crew.",
	],
	"kill": [
		"Target destroyed. IGOR would clap. IGOR has no hands. IGOR claps in heart.",
		"Is gone. Good shooting. For meat.",
		"{who} got one. IGOR is noting it under 'flukes'.",
		"Destroyed. That was somebody's cousin. Not IGOR's. IGOR checked first.",
	],
	"kill_streak": [
		"That is {n}. {who} is on what humans call a roll. IGOR calls it statistics catching up.",
		"{n} down. IGOR is moving {who} from 'liability' to 'possible liability'.",
	],
	"scanned": ["Sensors says: {name}. Now captain knows. Captain, say something."],
	"ghost": [
		"{who} has carefully scanned nothing. It was nothing. Radar has ghosts. {eng} should look at sensors.",
		"Scan complete. Result: empty space. Very thorough. The radar is seeing things.",
	],
	"weak_found": ["Weak spot found: at the back. Like all bullies. Get behind it."],
	"torp_hit": [
		"Torpedo in the weak spot. Very satisfying. IGOR is recording.",
		"Direct hit. IGOR felt that. In a good way. IGOR is told this is called joy.",
	],
	"torp_bounce": [
		"Torpedo bounced. Only the back vent, meat. The BACK.",
		"That torpedo cost more than {who}. It hit the front. The front is the strong bit.",
	],
	"hail_heard": [
		"Message received. {sns}: read it to captain. Out loud. With feeling.",
		"Radio is talking. Only {sns} can hear it. {sns}, do the voice.",
	],
	"radio_new": [
		"Radio is ringing. {sns}, turn the dial. It might be important. It will not be important.",
		"Somebody is calling. IGOR does not answer phones. IGOR has a policy.",
		"Incoming call. {sns}: tune in. If it is for IGOR, IGOR is out.",
	],
	"radio_done": [
		"{from} is satisfied. That is {reward} extra. Being polite pays. IGOR finds this unsettling.",
		"Done as asked. {from} sends {reward}. IGOR has put it in the tin.",
	],
	"radio_missed": [
		"{from} has hung up. Humans call this rude. IGOR calls it Tuesday.",
		"Too slow. {from} has stopped waiting. IGOR knows the feeling.",
	],
	"collected": [
		"{name} is aboard. Good catch. IGOR did not doubt. IGOR doubted a little.",
		"Got it. {shd} has hauled in {name}. IGOR will find somewhere to put it. On {who}'s side.",
	],
	"bonus": [
		"Stray pod aboard. That is {amount} extra. Finders keepers. This is actual space law.",
		"Bonus cargo. {amount} in the tin. IGOR will not ask whose it was.",
	],
	"step_done": [
		"Done. Next.",
		"Is done. IGOR is moderately impressed. Do not get used to it.",
		"Good. Next thing.",
		"That worked. IGOR has checked twice. It still worked.",
		"Tick. IGOR enjoys ticking things. It is as close as he gets to dancing.",
	],
	"mission_done": [
		"Mission complete. Ship is mostly in one piece. IGOR is proud. IGOR denies this.",
		"Is finished. IGOR has seen worse. Not often.",
		"Complete. IGOR had prepared a speech for failure. IGOR will keep it for next time.",
	],
	"mission_failed": [
		"Is over. Ship is gone. IGOR has seen worse. Not often. Rarely. Once.",
		"We have failed. IGOR will tell other robots it was solar flare.",
		"That did not work. IGOR has many notes. They are all the word 'no'.",
	],
	"idle": [
		"IGOR is watching. IGOR is always watching.",
		"Captain: talking is free. Please use it.",
		"Fun fact: robots never shout. Robots do not need to. Humans, please shout.",
		"IGOR was built to chart the paths of stars. IGOR now supervises a bin lorry. Is fine. IGOR is fine.",
		"Quiet in here. IGOR does not trust it.",
		"If anyone needs IGOR, IGOR is here. Being right. Quietly.",
		"IGOR has cousin who is a toaster. He seems happy. IGOR does not want to talk about it.",
		"Reminder: Pudding is not allowed on the consoles. Pudding is on the consoles.",
	],
	"quiet": [
		"Nothing has broken for one whole minute. IGOR is suspicious.",
		"A full minute without disaster. IGOR is marking the calendar.",
		"Everything is working. IGOR does not recognise this ship.",
	],
	"hull_low": [
		"Hull is under a third. The outside is very close to being the inside.",
		"Hull is low. IGOR has started saying goodbye to his favourite files.",
		"We are mostly holes now. Holes held together by {eng}.",
	],
	"glitch": [
		"IGOR detects a glitch. Somewhere. IGOR knows where. IGOR is not telling. Is more fun.",
		"Something on this ship has just stopped behaving. No, IGOR will not say what. Work it out. Use words.",
		"Glitch. One of you is about to say 'that's odd'. IGOR is waiting to see who.",
		"A part of the ship has developed an opinion. {eng} may want to look round the rooms.",
		"Ship has hiccup. Not telling you where. IGOR had to learn things the hard way. So will you.",
	],
	"glitch_fixed": [
		"Glitch is fixed. It took three of you. IGOR counted.",
		"Fixed. {eng} read the manual. Out loud. To other humans. IGOR is almost moved.",
	],
	"incident_drones": [
		"Company. Hegemony drones. {sns} should have a look. {wpn} should have more than a look.",
		"New blips. They are not here to help. Nothing out here is here to help.",
	],
	"incident_meteors": [
		"Meteors inbound. Captain can see them. {shd} cannot. You know what to do. Shout.",
		"Rocks. Coming this way. They are not aiming. They do not need to.",
	],
	"incident_grabber": [
		"Grabber drone incoming. It wants a cuddle. Do not let it cuddle.",
	],
	"incident_pod": [
		"Stray cargo pod nearby. Not on the job sheet. Worth extra if hauled in. Captain's call.",
		"IGOR sees a loose pod. Somebody's lost property. Could be ours. Captain decides.",
	],
	"incident_fright": [
		"Pudding heard a noise. Pudding is now unhappy. {shd}: you are needed. Softly.",
		"Something startled Pudding. IGOR did not do it. IGOR was nowhere near. IGOR is everywhere, but still.",
	],
	"board": [
		"Three jobs on the board. One is safe. One pays. They are not the same one.",
		"Job board. Pick with your heads. IGOR knows you will pick with your greed.",
		"Here are today's jobs. IGOR has ranked them by how much shouting each will need.",
		"Choose a job. Flames mean danger. More flames, more pay. More flames, more IGOR saying 'told you'.",
	],
	"board_safe": [
		"The safe one. Sensible. IGOR is surprised. Rent does not pay itself, though.",
		"A cautious choice. IGOR approves. The depot's accountant will not.",
	],
	"board_spicy": [
		"The dangerous one. Of course. IGOR will warm up the tow truck.",
		"Maximum flames. Bold. IGOR has updated everyone's next of kin.",
	],
	"part": [
		"IGOR found {name} in a skip. It is nearly new. It was nearly somebody else's.",
		"{name} is fitted. With tape. It will be fine. Fine is a wide word.",
	],
	"part_skip": [
		"No new parts. The ship stays exactly as bad as it was. Consistent.",
	],
	"shift_start": [
		"Shift begins. Three jobs. Rent is {rent}. IGOR believes in you. That was a test of IGOR's lying. It works.",
		"New shift. The depot wants {rent} by the end. The depot always wants.",
	],
	"rent_made": [
		"Rent is paid. The crew keeps its berth. IGOR keeps his job. Everybody loses.",
		"You made rent. IGOR had bet against you. IGOR bet with himself. IGOR still lost.",
		"Paid in full. The depot manager smiled. IGOR has never seen that before. It was unpleasant.",
	],
	"rent_missed": [
		"Rent is short by {short}. IGOR has received a formal notice. It is addressed to 'The Occupants'. That is you.",
		"Short by {short}. The depot is 'disappointed'. IGOR has been disappointed for years. Welcome.",
		"Not enough. {short} short. IGOR will tell the depot it is in the post. It is not in the post.",
	],
	"new_card": [
		"Something new has been added to your troubles. IGOR will explain at the next briefing. IGOR is looking forward to it.",
	],
	"joined": [
		"{who} has joined. IGOR has opened a file. It is empty. IGOR expects that to change.",
		"{who} is aboard. One more pair of hands. IGOR counts hands, not skills.",
		"Welcome, {who}. Please do not press anything until IGOR has finished sighing.",
	],
	"left": [
		"{who} has left. A robot will take over. Standards will rise.",
		"{who} is gone. IGOR will not say he misses them. IGOR will not say a lot of things.",
	],
	"late": [
		"We are behind the clock. IGOR is the clock. IGOR is disappointed in both of us.",
		"Running late. IGOR does not get tired. IGOR does get bored.",
	],
	"flip": ["{who} is doing two jobs. Badly, but two."],
}

## what IGOR says about each crew member when he reads out the shift's staff review
const REVIEWS: Dictionary = {
	"captain": ["Captain talked a great deal. Some of it was instructions.", "Captain pointed at things. The things remained pointed at.", "Captain was confident. That is not the same as correct. It was sometimes the same."],
	"helm": ["Helm steered. IGOR uses the word loosely.", "Helm found most of the gaps between the rocks.", "Helm turned the right way more often than not. IGOR counted."],
	"engines": ["Engines provided speed. Occasionally the right amount.", "Engines treated the red line as a personal challenge.", "Engines kept us moving. Sometimes forwards."],
	"weapons": ["Weapons hit things. Some of them were the right things.", "Weapons was enthusiastic. Accuracy is a different word.", "Weapons made a lot of noise. Pudding has filed a complaint."],
	"sensors": ["Sensors knew what everything was. Eventually.", "Sensors answered the radio. This already puts them above IGOR.", "Sensors scanned it. Then scanned it again to be sure. It was a rock."],
	"shields": ["Shields was usually between us and the trouble. Usually.", "Shields petted Pudding. IGOR has no comment.", "Shields blocked what could be blocked and apologised for the rest."],
	"engineer": ["Engineer kept the ship in one piece. The piece got smaller.", "Engineer has used all the tape. All of it.", "Engineer read IGOR's manual. Nobody has ever done that before."],
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
	return fill(str(arr[idx]), ctx)

static func fill(s: String, ctx: Dictionary) -> String:
	for k in ctx.keys():
		s = s.replace("{" + str(k) + "}", str(ctx[k]))
	return s

static func review(seat: String) -> String:
	var arr: Array = REVIEWS.get(seat, [])
	return str(arr[randi() % arr.size()]) if not arr.is_empty() else ""
