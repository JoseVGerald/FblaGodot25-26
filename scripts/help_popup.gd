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

	# Create LLM Assistant instance
	llm_assistant = LLMAssistant.new()
	add_child(llm_assistant)

	# Connect signals
	llm_assistant.response_received.connect(_on_response_received)
	llm_assistant.request_started.connect(_on_request_started)
	llm_assistant.request_failed.connect(_on_request_failed)

	_wire_faq_buttons()

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
	var message_container = HBoxContainer.new()
	message_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 33)
	var font := UITheme.get_pixel_font()
	if font:
		label.add_theme_font_override("font", font)
	
	if is_user:
		# User message - right aligned, blue tint
		label.text = "You: " + text
		label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	elif is_error:
		# Error message - red
		label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	else:
		# Assistant message - green tint
		label.text = "Assistant: " + text
		label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
	
	message_container.add_child(label)
	chat_history.add_child(message_container)
	
	# Auto-scroll to bottom after a frame
	await get_tree().process_frame
	chat_scroll.scroll_vertical = chat_scroll.get_v_scroll_bar().max_value

# Updated on 2026-04-19
