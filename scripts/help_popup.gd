# COMMIT: Achievements and Catch Minigame Update
extends CanvasLayer

@onready var chat_history = $Panel/MainHBox/RightSection/ChatContainer/ChatScroll/ChatHistory
@onready var chat_scroll = $Panel/MainHBox/RightSection/ChatContainer/ChatScroll
@onready var question_input = $Panel/MainHBox/RightSection/InputContainer/QuestionInput
@onready var send_btn = $Panel/MainHBox/RightSection/InputContainer/SendBtn
@onready var status_label = $Panel/MainHBox/RightSection/StatusLabel
@onready var faq_box = $Panel/MainHBox/RightSection/FaqBox

var llm_assistant: LLMAssistant = null
var is_waiting_for_response: bool = false

# FAQ pools: each key maps to { "question": ..., "answers": [variants] }.
# When an FAQ button is clicked we show the question as a user message and
# pick a random answer variant. All variants convey the same info so the
# reply feels dynamic even though it's canned.
const FAQ_DATA := {
	"FaqCash": {
		"question": "How do I check my cash?",
		"answers": [
			"Your cash is shown on the bottom HUD next to the $ icon on the left side — it updates live whenever you spend or earn.",
			"Look at the bottom-left of the screen: the number next to the $ icon is your current cash on hand.",
			"Open the Finance menu (F) to see cash, savings, budgets, and loans all in one place — cash is the top line.",
			"Glance at the $ icon in the lower-left HUD — the number right beside it is your live wallet balance.",
			"Cash is always visible on the bottom HUD. Look for the dollar sign in the left corner, that's your current total.",
			"You can hit F to open the Financial Hub — it shows wallet, savings, and everything else in one view.",
			"The bottom HUD keeps a running display next to the $ symbol; that's your spending money at any moment.",
			"Check the HUD at the bottom of the screen — the $ figure on the left updates every time money moves in or out.",
			"Either peek at the $ indicator in the HUD or press F for a full breakdown in the Finance menu.",
			"Your wallet number lives in the bottom-left HUD, and the Finance menu (F) gives you the full picture including savings.",
		],
	},
	"FaqBudgets": {
		"question": "How do I change budgets?",
		"answers": [
			"Open the Finance menu (F), switch to the Budgets tab, and adjust the weekly limit for Food, Vet, or Travel.",
			"Click the Finance button in the top-right HUD, then use the +/- controls in the Budgets panel to raise or lower each category's weekly cap.",
			"Budgets live in the Finance panel. Set a weekly $ limit per category; they reset automatically every 7 in-game days.",
			"Press F, go to Budget Planner, and slide each category's limit up or down to whatever feels right.",
			"In the Finance overlay, the Budget Planner tab has sliders for Food, Vet, and Travel — drag them to set your caps.",
			"Each category (Food, Vet, Travel) has its own slider in the Budget Planner tab of the Finance menu.",
			"Hit F to open Finance, pick Budget Planner, and tweak the three weekly limits to suit your playstyle.",
			"Your weekly spending caps are in Finance → Budget Planner. Adjust the slider per category; limits refresh every 7 days.",
			"Change budgets through the Finance menu's Budget Planner tab — each row has a slider and a live limit display.",
			"Budget Planner (inside Finance, press F) is where you drag Food/Vet/Travel sliders to set your own weekly ceilings.",
		],
	},
	"FaqFeed": {
		"question": "How do I feed my dog?",
		"answers": [
			"Press 1 while your dog is following you — it'll run to the food bowl. You need at least 1 food in inventory (buy from the shop).",
			"Make sure you have food, then hit the 1 key. The dog walks to the bowl, eats, and hunger goes up.",
			"Click on your dog to open the needs menu, or press 1 to send it straight to the food bowl. Food comes from the shop.",
			"Hit 1 to send your dog to the food bowl — just make sure you've stocked up on food from the shop first.",
			"Buy food at the shop, then press 1 anywhere; the dog will jog to the bowl and chow down.",
			"Feeding is on the 1 key. Empty inventory? Grab a bag of food at the shop before trying.",
			"Tap 1 near your dog; it heads to the bowl and eats, which fills its hunger meter back up.",
			"Press the 1 key to trigger feeding. If nothing happens, you probably need to restock food at the shop.",
			"To feed: make sure you've got food in inventory, then use the 1 shortcut and the dog handles the rest.",
			"The 1 key is your feed command — shop for food first, then press 1 and the dog walks itself to the bowl.",
		],
	},
	"FaqSim": {
		"question": "How do I sim days?",
		"answers": [
			"Press B anywhere — or click the date label in the HUD. It fast-forwards up to 7 days in a single transition.",
			"Tap B to sim a week. It'll stop early if you run out of food/water or your dog gets sick.",
			"Use B (or click the date text on the HUD) to simulate a week. Supplies are consumed per day, so stock up first.",
			"B fast-forwards up to 7 days at once — clicking the HUD date works too. Stock supplies first.",
			"Hit the B key (or the date label on the HUD) to skip ahead. The sim halts early if supplies run out.",
			"Want to skip time? Press B, or just click the date display. Make sure food/water are topped up first.",
			"Simulate a week with B. The sim auto-stops if your dog goes hungry, thirsty, or sick during the skip.",
			"Press B anywhere, or click the in-game date on your HUD — both fast-forward up to 7 days.",
			"Use the B shortcut to sim. The sim pauses on critical events (empty food, low water, sickness).",
			"Simming = press B. The date label on the HUD is also clickable and does the same thing.",
		],
	},
	"FaqStuck": {
		"question": "My dog seems stuck — what do I do?",
		"answers": [
			"If the dog is more than ~250px away it teleports back to you automatically. Try walking a bit — that usually unsticks it.",
			"Walk a few steps away from the dog's current spot; it will warp to catch up once the distance is big enough.",
			"Move your player around. The dog re-targets your position every frame and will teleport back if it falls too far behind.",
			"Just start walking — once the dog drifts more than ~250px behind, it auto-teleports to your position.",
			"Stuck dog? Keep moving; the follow AI warps it to you whenever the gap gets too large.",
			"Take a stroll. The dog snaps back to your side automatically if it falls behind by a couple hundred pixels.",
			"The dog's follow logic auto-corrects. Walk somewhere else and it'll teleport back — no manual fix needed.",
			"Try putting some distance between you and the dog. Past a threshold it instantly warps to catch up.",
			"Usually a few steps away will do it — the dog teleports to you once it's too far behind.",
			"Don't worry about it: the dog has an auto-warp when it falls behind, so just keep playing and it'll catch up.",
		],
	},
	"FaqTravel": {
		"question": "How do I travel?",
		"answers": [
			"Press the home/taxi button on the bottom HUD and pick a destination — Home, Store, Vet, or Park. Each ride costs $10.",
			"Tap the home icon in the bottom HUD to open the taxi menu. Pick where to go; the fare is deducted from cash.",
			"Use the taxi menu (home icon, bottom HUD). Choose Store for supplies, Vet for care, Park for catch, or Home to return.",
			"Open the taxi menu from the bottom HUD, select your destination, and pay $10 for the ride.",
			"The home icon in the HUD opens a taxi. Pick Home, Store, Vet, or Park — fare is a flat $10 each trip.",
			"Travel runs through the taxi UI (bottom HUD icon). Four destinations, $10 per ride, deducted from cash.",
			"Hit the taxi button on the HUD, then tap a destination. $10 comes out of your wallet per trip.",
			"Click the home/taxi icon in the bottom HUD to bring up destinations. Rides are $10 regardless of distance.",
			"Taxi menu lives on the bottom HUD. Select Store, Vet, Park, or Home — each ride is a flat $10.",
			"Use the taxi (home icon, bottom HUD). One click opens destinations; $10 fare applies per trip.",
		],
	},
}

func _ready():
	UITheme.apply_overlay_theme(self )
	_apply_redesign_styling()

	# Create LLM Assistant instance
	llm_assistant = LLMAssistant.new()
	add_child(llm_assistant)

	# Connect signals
	llm_assistant.response_received.connect(_on_response_received)
	llm_assistant.request_started.connect(_on_request_started)
	llm_assistant.request_failed.connect(_on_request_failed)

	_wire_faq_buttons()
	_style_faq_buttons()

## Runtime redesign pass: replace the RichTextLabel body with spec'd rule cards,
## restyle panels/inputs/buttons to match the April 2026 design tokens.
func _apply_redesign_styling() -> void:
	# Outer panel — navy shell.
	var panel := get_node_or_null("Panel")
	if panel is PanelContainer:
		UITheme.style_panel(panel)

	# Left header — dark-maroon plaque accent (matches needs_menu titles).
	var left_header := get_node_or_null("Panel/MainHBox/LeftSection/Header")
	if left_header is Label:
		left_header.text = "Game Rules"
		left_header.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)

	# Replace the existing RichTextLabel body with proper rule cards.
	var body := get_node_or_null("Panel/MainHBox/LeftSection/Body")
	if body is RichTextLabel:
		var parent := body.get_parent()
		var rules_list := VBoxContainer.new()
		rules_list.name = "RulesList"
		rules_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rules_list.add_theme_constant_override("separation", 14)
		for card in _build_rule_cards():
			rules_list.add_child(card)
		parent.add_child(rules_list)
		parent.move_child(rules_list, body.get_index())
		body.queue_free()

	# Left "Got it!" button — green confirm, rendered in the pixel style.
	var got_it := get_node_or_null("Panel/MainHBox/LeftSection/CloseBtn")
	if got_it is Button:
		UITheme.style_pixel_button_colored(got_it, UITheme.CLR_GREEN)

	# Right-column chat header + welcome (dark ink on the cream chat panel).
	var chat_hdr := get_node_or_null("Panel/MainHBox/RightSection/ChatHeader")
	if chat_hdr is Label:
		chat_hdr.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	var welcome := get_node_or_null("Panel/MainHBox/RightSection/ChatContainer/ChatScroll/ChatHistory/WelcomeLabel")
	if welcome is Label:
		welcome.add_theme_color_override("font_color", UITheme.CLR_INK)

	# "Thinking…" / error status line — readable maroon on cream.
	if status_label:
		status_label.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)

	# FAQ label + inline input/send button.
	var faq_label := get_node_or_null("Panel/MainHBox/RightSection/FaqLabel")
	if faq_label is Label:
		faq_label.text = "QUICK QUESTIONS"
		faq_label.add_theme_color_override("font_color", Color(UITheme.CLR_INK.r, UITheme.CLR_INK.g, UITheme.CLR_INK.b, 0.75))
		faq_label.add_theme_font_size_override("font_size", 20)
	_style_input()
	_style_send_btn()

func _build_rule_cards() -> Array:
	var specs := [
		["Weekly Income",     "You receive $150 every 7 in-game days automatically."],
		["Budgets",           "Set weekly limits for Food, Vet & Travel. Budgets reset every 7 days."],
		["Emergency Savings", "Start with $200. Auto-pays essential costs if wallet runs dry. Earns 5% daily interest."],
		["Simulate Week",     "Press B or click the date in the HUD to skip up to 7 days. Stock supplies first."],
		["Dog Needs",         "Check Hunger, Thirst, Energy & Health in the Needs panel. Below 30 = critical."],
	]
	var cards: Array = []
	for s in specs:
		cards.append(_make_rule_card(s[0], s[1]))
	return cards

func _make_rule_card(title: String, body_text: String) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color     = UITheme.CLR_CREAM_LT                 # light card, ink text
	sb.border_color = UITheme.CLR_INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)                            # crisp pixel edges
	sb.content_margin_left   = 0                           # stripe owns the left edge
	sb.content_margin_right  = 14
	sb.content_margin_top    = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)

	# Row layout: full-height orange accent bar + text column. (PanelContainer
	# stretches its single child, so the stripe must be a real layout element,
	# not an overlaid ColorRect — an overlay would fill the whole card.)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var stripe := ColorRect.new()
	stripe.color = UITheme.CLR_ORANGE_PX
	stripe.custom_minimum_size = Vector2(6, 0)
	stripe.size_flags_vertical = Control.SIZE_FILL
	row.add_child(stripe)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_color_override("font_color", UITheme.CLR_MAROON_D)
	title_lbl.add_theme_font_size_override("font_size", 30)
	var pf := UITheme.get_pixel_font()
	if pf: title_lbl.add_theme_font_override("font", pf)
	vbox.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.text = body_text
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_color_override("font_color", UITheme.CLR_INK)
	body_lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(body_lbl)

	row.add_child(vbox)
	card.add_child(row)
	return card

func _style_faq_buttons() -> void:
	if not faq_box: return
	for child in faq_box.get_children():
		if child is Button:
			_style_faq_btn(child)

func _style_faq_btn(btn: Button) -> void:
	btn.add_theme_color_override("font_color", UITheme.CLR_INK)
	btn.add_theme_color_override("font_hover_color", UITheme.CLR_INK)
	btn.add_theme_color_override("font_pressed_color", UITheme.CLR_INK)
	btn.add_theme_font_size_override("font_size", 22)
	var pf := UITheme.get_pixel_font()
	if pf: btn.add_theme_font_override("font", pf)
	var sb := StyleBoxFlat.new()
	sb.bg_color     = UITheme.CLR_TAN                      # tan pill, ink text
	sb.border_color = UITheme.CLR_INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h: StyleBoxFlat = sb.duplicate()
	sb_h.bg_color = UITheme.CLR_TAN_HI
	btn.add_theme_stylebox_override("hover", sb_h)
	var sb_p: StyleBoxFlat = sb.duplicate()
	sb_p.bg_color = UITheme.CLR_TAN_DRK
	btn.add_theme_stylebox_override("pressed", sb_p)

func _style_input() -> void:
	if not question_input: return
	# White field / black text via the shared brand helper — maximally legible.
	UITheme.style_line_edit(question_input)
	var sb_f := StyleBoxFlat.new()
	sb_f.bg_color = Color.WHITE
	sb_f.border_color = UITheme.CLR_ORANGE_PX
	sb_f.set_border_width_all(3)
	sb_f.border_width_bottom = 4
	sb_f.set_corner_radius_all(4)
	sb_f.content_margin_left = 12
	sb_f.content_margin_right = 12
	sb_f.content_margin_top = 6
	sb_f.content_margin_bottom = 6
	question_input.add_theme_stylebox_override("focus", sb_f)

func _style_send_btn() -> void:
	if not send_btn: return
	send_btn.text = "Ask"
	UITheme.style_pixel_button_colored(send_btn, UITheme.CLR_GREEN)

func _wire_faq_buttons() -> void:
	# Connect each FAQ button to _on_faq_pressed(key) so we can look up the
	# matching question/answer pool in FAQ_DATA.
	if not faq_box:
		return
	for child in faq_box.get_children():
		if child is Button and FAQ_DATA.has(child.name):
			var key: String = child.name
			child.pressed.connect(func(): _on_faq_pressed(key))

func _on_faq_pressed(key: String) -> void:
	# Don't let the player spam FAQs while the real LLM is mid-request.
	if is_waiting_for_response:
		return
	var entry: Dictionary = FAQ_DATA.get(key, {})
	if entry.is_empty():
		return
	var question: String = entry["question"]
	var answers: Array = entry["answers"]
	add_chat_message(question, true)
	var pick: String = answers[randi() % answers.size()]
	add_chat_message(pick, false)

func _input(event):
	# ESC closes the help popup without toggling the pause menu
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()

func _on_close_btn_pressed():
	queue_free()

func _on_send_btn_pressed():
	_submit_question()

func _on_question_submitted(_text: String):
	_submit_question()

func _submit_question():
	var question = question_input.text.strip_edges()
	if question.is_empty() or is_waiting_for_response:
		return
	
	# Add user question to chat
	add_chat_message(question, true)
	
	# Clear input
	question_input.text = ""
	
	# Send to LLM
	llm_assistant.ask_question(question)

func _on_request_started():
	is_waiting_for_response = true
	status_label.text = "Thinking..."
	send_btn.disabled = true
	question_input.editable = false

func _on_response_received(response: String):
	is_waiting_for_response = false
	status_label.text = ""
	send_btn.disabled = false
	question_input.editable = true
	
	# Add assistant response to chat
	add_chat_message(response, false)
	
	# Focus back on input
	question_input.grab_focus()

func _on_request_failed(error: String):
	is_waiting_for_response = false
	status_label.text = ""
	send_btn.disabled = false
	question_input.editable = true
	
	# Show error in chat
	add_chat_message("Error: " + error, false, true)
	
	question_input.grab_focus()

func add_chat_message(text: String, is_user: bool, is_error: bool = false):
	# Row that aligns the bubble to left (assistant/error) or right (user).
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_END if is_user else BoxContainer.ALIGNMENT_BEGIN

	var bubble := PanelContainer.new()
	bubble.custom_minimum_size.x = 240
	bubble.size_flags_horizontal = (
		Control.SIZE_SHRINK_END if is_user else Control.SIZE_SHRINK_BEGIN
	)

	var sb := StyleBoxFlat.new()
	if is_user:
		sb.bg_color     = UITheme.CLR_GOLD                 # warm "you" bubble
		sb.border_color = UITheme.CLR_INK
	elif is_error:
		sb.bg_color     = Color("#EF5350", 0.18)
		sb.border_color = Color("#EF5350")
	else:
		sb.bg_color     = UITheme.CLR_CREAM_LT             # assistant bubble
		sb.border_color = UITheme.CLR_INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	# Flatten one corner so the bubble "points" toward its speaker.
	if is_user:
		sb.corner_radius_bottom_right = 3
	else:
		sb.corner_radius_bottom_left = 3
	sb.set_content_margin_all(12)
	bubble.add_theme_stylebox_override("panel", sb)

	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 220
	label.add_theme_font_size_override("font_size", 26)
	if is_error:
		label.add_theme_color_override("font_color", Color("#b71c1c"))
	else:
		label.add_theme_color_override("font_color", UITheme.CLR_INK)
	bubble.add_child(label)

	row.add_child(bubble)
	chat_history.add_child(row)

	# Auto-scroll to bottom after a frame
	await get_tree().process_frame
	chat_scroll.scroll_vertical = chat_scroll.get_v_scroll_bar().max_value

# Updated on 2026-04-19
