@tool
class_name LDData
extends RefCounted
## Bank Blitz — Loan Decision Desk data: applicants, lending policy, scoring.
## Direct port of the reference bank/data.js. Avatars reuse BBPix (same 16px faces).

# townspeople you'd meet in a game world: [name, occupation]
const TOWNSFOLK := [
	["Mabel", "Baker"], ["Gus", "Blacksmith"], ["Pearl", "Seamstress"], ["Sven", "Fisherman"],
	["Otto", "Carpenter"], ["Rosa", "Innkeeper"], ["Cliff", "Miner"], ["Hazel", "Teacher"],
	["Bram", "Farmer"], ["Trudy", "Herbalist"], ["Wade", "Sailor"], ["Ida", "Potter"],
	["Nash", "Rancher"], ["Vera", "Tailor"], ["Roscoe", "Butcher"], ["Coraline", "Florist"],
	["Dwight", "Locksmith"], ["Pip", "Courier"], ["Mort", "Gravedigger"], ["Olive", "Beekeeper"],
	["Hank", "Brewer"], ["Lulu", "Weaver"], ["Tito", "Cobbler"], ["Bex", "Mapmaker"],
]

# productive purposes the bank funds
const GOOD_PURPOSES := [
	"Open a bakery", "Buy a fishing boat", "Repair the roof", "Cover medical bills",
	"Pay tuition", "Buy a delivery cart", "Expand the farm", "New blacksmith forge",
	"Restock the shop", "Consolidate old debt", "Buy seed & livestock", "Open a tailor stall",
]
# speculative purposes policy prohibits
const BANNED_PURPOSES := [
	"Bet on the horse races", "Buy lottery tickets", "Invest in sea-monster coins",
	"Fund a get-rich scheme", "High-stakes card game", "Speculate on tulip bulbs",
]
const COLLATERAL_ITEMS := ["Horse & cart", "Workshop tools", "Farmland deed", "Fishing boat",
	"Family jewelry", "Shop inventory", "Timber lot"]

# the bank's lending policy (ground truth, also shown to the player)
const MAX_DTI := 0.40
const MIN_CREDIT := 600


## Decide whether a loan is risky and what the correct call is.
## Mutates and returns the application dictionary.
static func eval_risk(app: Dictionary) -> Dictionary:
	var dti_after: float = (float(app["debt"]) + float(app["payment"])) / float(app["income"])
	app["dti_after"] = dti_after
	app["secured"] = int(app["collateral_value"]) >= int(app["amount"])
	var reasons: Array = []
	var risky := false
	if dti_after > MAX_DTI:
		risky = true
		reasons.append("Debt load too high (DTI %d%% > 40%%)" % int(round(dti_after * 100.0)))
	if int(app["credit_score"]) < MIN_CREDIT and not app["secured"]:
		risky = true
		reasons.append("Credit %d under 600 and loan is unsecured" % int(app["credit_score"]))
	if app["purpose_banned"]:
		risky = true
		reasons.append("Prohibited purpose (speculation/gambling)")
	app["risky"] = risky
	app["reasons"] = reasons
	app["correct"] = "deny" if risky else "approve"
	return app


## Build one loan application for the given day (difficulty climbs with day).
static func generate_application(day: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var who: Array = TOWNSFOLK[rng.randi() % TOWNSFOLK.size()]

	var income: int = 1500 + int(round((rng.randf() * 5500.0) / 50.0)) * 50          # 1,500 – 7,000 / mo
	var terms := [12, 24, 36, 48, 60]
	var term: int = terms[rng.randi() % terms.size()]
	var amount: int = 2000 + int(round((rng.randf() * 16000.0) / 100.0)) * 100        # 2,000 – 18,000
	var payment: int = int(round(float(amount) / float(term)))
	var debt: int = int(round(income * (0.05 + rng.randf() * 0.38) / 10.0)) * 10      # existing monthly debt
	var credit: int = 540 + (rng.randi() % 261)                                       # 540 – 800

	# purpose (banned chance climbs with day)
	var banned_chance: float = minf(0.42, 0.12 + day * 0.045)
	var purpose: String
	var purpose_banned: bool
	if rng.randf() < banned_chance:
		purpose = BANNED_PURPOSES[rng.randi() % BANNED_PURPOSES.size()]
		purpose_banned = true
	else:
		purpose = GOOD_PURPOSES[rng.randi() % GOOD_PURPOSES.size()]
		purpose_banned = false

	# collateral (50% of applicants bring some)
	var collateral_label := ""
	var collateral_value := 0
	if rng.randf() < 0.5:
		collateral_value = int(round(amount * (0.25 + rng.randf() * 1.0) / 100.0)) * 100
		collateral_label = COLLATERAL_ITEMS[rng.randi() % COLLATERAL_ITEMS.size()]

	# later days: push values toward the thresholds to force careful reads
	if day >= 2:
		if rng.randf() < 0.45:
			var t: float = 0.40 + (rng.randf() - 0.5) * 0.07         # target DTI 0.365–0.435
			debt = maxi(0, int(round((t * income - payment) / 10.0)) * 10)
		if rng.randf() < 0.4:
			credit = 584 + (rng.randi() % 33)                        # 584–616, near the 600 line

	var patience_max: float = maxf(15.0, 32.0 - day * 1.8)
	var app := {
		"name": who[0], "occupation": who[1], "avatar_seed": rng.randi(),
		"income": income, "debt": debt, "amount": amount, "term": term, "payment": payment,
		"credit_score": credit, "purpose": purpose, "purpose_banned": purpose_banned,
		"collateral_label": collateral_label, "collateral_value": collateral_value,
		"patience_max": patience_max, "patience": patience_max, "mood": "neutral", "resolved": false,
	}
	return eval_risk(app)


## Money with thousands separators, e.g. -$1,200.
static func fmt_money(n: float) -> String:
	var neg := n < 0.0
	var v := int(round(absf(n)))
	return ("-$" if neg else "$") + _commas(v)


static func _commas(v: int) -> String:
	var s := str(v)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


static func fmt_pct(f: float) -> String:
	return "%d%%" % int(round(f * 100.0))
