# shop_menu.gd
# Shop / purchase screen — buy food, water, and prescriptions.
# Redesigned from the ground up to match the game's premium minigame UI standards.
extends CanvasLayer
signal shop_closed

# ── Color palette matching UITheme ─────────────────────────────────────────────
const CLR_NAVY  := Color("#1a2a4a")
const CLR_SKY   := Color("#4A90D9")
const CLR_GREEN := Color("#4CAF50")
const CLR_RED   := Color("#EF5350")

# Cart State
var food_cart_count := 0
var water_cart_count := 0
var bundle_cart_count := 0
var prescription_selected := false
var prescription_available := false
# Fake / cosmetic item cart counts (these deduct money but have no major gameplay effect)
var grooming_cart_count := 0
var toy_cart_count := 0

# Dynamic pricing (affected by daily deals)
var food_price_current := 0
var water_price_current := 0
var prescription_price_current := 0
var bundle_price_current := 0
# Cosmetic item base prices (static, never discounted)
const GROOMING_PRICE := 8
const TOY_PRICE := 5

# Daily Deal state
var active_deal_title := ""
var active_deal_desc := ""

# UI Node References
var main_panel : PanelContainer
var shopkeeper_avatar : TextureRect
var speech_label : Label
var deal_strip : PanelContainer
var deal_title_label : Label
var deal_desc_label : Label

# Item nodes
var food_owned_label : Label
var food_recom_badge : Label
var food_price_label : Label
var food_count_label : Label

var water_owned_label : Label
var water_recom_badge : Label
var water_price_label : Label
var water_count_label : Label

var presc_card : PanelContainer
var presc_owned_label : Label
var presc_price_label : Label
var presc_checkbox : CheckBox

var bundle_price_label : Label
var bundle_count_label : Label

var toy_card : PanelContainer

# Cosmetic / fake item nodes
var grooming_price_label : Label
var grooming_count_label : Label
var toy_price_label : Label
var toy_count_label : Label

# Cart nodes
var cart_items_list : VBoxContainer
var total_label : Label
var funds_label : Label
var purchase_btn : Button
var clear_btn : Button

func _ready() -> void:
	visible = false
	_build_ui()

# Center main panel inside viewport dynamically
func _on_resized() -> void:
	if is_instance_valid(main_panel):
		var vp = get_viewport().get_visible_rect().size
		var pw = minf(2200.0, vp.x - 40.0)
		var ph = minf(1100.0, vp.y - 150.0 - 40.0) # Usable height excluding bottom HUD (150px)
		main_panel.custom_minimum_size = Vector2(pw, ph)
		
		# Allow container to update its size to combined minimums, then center in usable area
		var actual_size = main_panel.get_combined_minimum_size()
		main_panel.size = actual_size
		main_panel.position.x = (vp.x - actual_size.x) * 0.5
		main_panel.position.y = (vp.y - 150.0 - actual_size.y) * 0.5
		main_panel.pivot_offset = actual_size * 0.5

# Programmatically build the redesigned high-polish UI
func _build_ui() -> void:
	# Clean any old programmatic nodes except background ColorRect
	for child in get_children():
		if child.name != "Background":
			child.queue_free()

	# Main Panel Container
	main_panel = PanelContainer.new()
	main_panel.name = "Panel"
	main_panel.custom_minimum_size = Vector2(2200, 1100)
	add_child(main_panel)
	
	# Initial scale and modulation for enter animations
	main_panel.scale = Vector2.ONE
	main_panel.modulate = Color.WHITE
	
	_on_resized()
	get_viewport().size_changed.connect(_on_resized)


	# VBox Container inside Main Panel (adds spacing between sections)
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 16)
	main_panel.add_child(vbox)

	# 1. Header Row (Plaque Title + Close Button)
	var header = HBoxContainer.new()
	header.name = "Header"
	vbox.add_child(header)

	# Title Plaque Container (matches cutscene title banner style)
	var title_plaque = PanelContainer.new()
	title_plaque.name = "TitlePlaque"
	var plaque_sb = StyleBoxFlat.new()
	plaque_sb.bg_color = UITheme.CLR_CREAM
	plaque_sb.border_color = UITheme.CLR_INK
	plaque_sb.border_width_left = 4
	plaque_sb.border_width_top = 4
	plaque_sb.border_width_right = 4
	plaque_sb.border_width_bottom = 8 # 3D Depth
	plaque_sb.content_margin_left = 28
	plaque_sb.content_margin_right = 28
	plaque_sb.content_margin_top = 8
	plaque_sb.content_margin_bottom = 8
	plaque_sb.anti_aliasing = false
	plaque_sb.set_corner_radius_all(0)
	title_plaque.add_theme_stylebox_override("panel", plaque_sb)
	header.add_child(title_plaque)

	var title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "BUDDY'S BOUTIQUE 🏪"
	title_label.add_theme_font_override("font", UITheme.get_pixel_font())
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", UITheme.CLR_CREAM_LT)
	title_label.add_theme_color_override("font_outline_color", UITheme.CLR_INK)
	title_label.add_theme_constant_override("outline_size", 12)
	title_plaque.add_child(title_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	# Close Button
	var close_btn = Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(64, 64)
	header.add_child(close_btn)
	close_btn.pressed.connect(_on_close_btn_pressed)
	close_btn.add_theme_font_size_override("font_size", 32)

	# 2. Decorative Divider Row (🐾 ✦ 🐾)
	var divider = HBoxContainer.new()
	divider.name = "Divider"
	divider.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(divider)

	var left_line = ColorRect.new()
	left_line.color = UITheme.CLR_INK
	left_line.custom_minimum_size = Vector2(150, 4)
	left_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.add_child(left_line)

	var center_lbl = Label.new()
	center_lbl.text = " 🐾 ✦ 🐾 "
	center_lbl.add_theme_font_override("font", UITheme.get_pixel_font())
	center_lbl.add_theme_font_size_override("font_size", 24)
	center_lbl.add_theme_color_override("font_color", UITheme.CLR_INK)
	divider.add_child(center_lbl)

	var right_line = ColorRect.new()
	right_line.color = UITheme.CLR_INK
	right_line.custom_minimum_size = Vector2(150, 4)
	right_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.add_child(right_line)

	# 3. Main content columns
	var columns = HBoxContainer.new()
	columns.name = "Columns"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	vbox.add_child(columns)

	# ── Left Column: Shopkeeper & News ─────────────────────────────────────────
	var left_col = VBoxContainer.new()
	left_col.name = "LeftCol"
	left_col.custom_minimum_size = Vector2(400, 0)
	left_col.add_theme_constant_override("separation", 12)
	columns.add_child(left_col)

	# Shopkeeper Portrait frame
	var sk_portrait_card = PanelContainer.new()
	sk_portrait_card.name = "ShopkeeperPortrait"
	left_col.add_child(sk_portrait_card)
	
	# Draw Avatar procdurally (Crisp nearest filter)
	shopkeeper_avatar = TextureRect.new()
	shopkeeper_avatar.name = "Avatar"
	shopkeeper_avatar.custom_minimum_size = Vector2(140, 140)
	shopkeeper_avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shopkeeper_avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sk_portrait_card.add_child(shopkeeper_avatar)

	# Shopkeeper reactive speech bubble
	var speech_card = PanelContainer.new()
	speech_card.name = "SpeechCard"
	speech_card.custom_minimum_size = Vector2(0, 100)
	left_col.add_child(speech_card)

	speech_label = Label.new()
	speech_label.name = "SpeechLabel"
	speech_label.text = "Welcome! Need anything for your pet today?"
	speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_label.add_theme_font_size_override("font_size", 24)
	speech_label.add_theme_color_override("font_color", Color.WHITE)
	speech_card.add_child(speech_label)

	# ── "DEALS & ADVERTISEMENTS" section title ────────────────────────────────────
	var deals_title = Label.new()
	deals_title.text = "DEALS & ADVERTISEMENTS"
	deals_title.add_theme_font_override("font", UITheme.get_pixel_font())
	deals_title.add_theme_font_size_override("font_size", 32)
	deals_title.add_theme_color_override("font_color", UITheme.CLR_INK)
	left_col.add_child(deals_title)

	# Today's Daily Deal section
	deal_strip = PanelContainer.new()
	deal_strip.name = "DealStrip"
	left_col.add_child(deal_strip)

	var deal_vbox = VBoxContainer.new()
	deal_vbox.add_theme_constant_override("separation", 4)
	deal_strip.add_child(deal_vbox)

	deal_title_label = Label.new()
	deal_title_label.name = "DealTitle"
	deal_title_label.text = "TODAY'S SPECIAL DEAL"
	deal_title_label.add_theme_font_override("font", UITheme.get_pixel_font())
	deal_title_label.add_theme_font_size_override("font_size", 32)
	deal_title_label.add_theme_color_override("font_color", Color("#ffd84d"))
	deal_vbox.add_child(deal_title_label)

	deal_desc_label = Label.new()
	deal_desc_label.name = "DealDesc"
	deal_desc_label.text = "Have a great day!"
	deal_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	deal_desc_label.add_theme_font_size_override("font_size", 24)
	deal_desc_label.add_theme_color_override("font_color", Color.WHITE)
	deal_vbox.add_child(deal_desc_label)

	# ── Advertisement panels (item-related promos & tips) ────────────────────────
	# Ad 2 — Water / hydration promotion
	var ad2 = PanelContainer.new()
	ad2.name = "AdPanel2"
	left_col.add_child(ad2)
	var ad2_vbox = VBoxContainer.new()
	ad2_vbox.add_theme_constant_override("separation", 4)
	ad2.add_child(ad2_vbox)
	var ad2_title_lbl = Label.new()
	ad2_title_lbl.text = "💧 HYDRATION MATTERS"
	ad2_title_lbl.add_theme_font_override("font", UITheme.get_pixel_font())
	ad2_title_lbl.add_theme_font_size_override("font_size", 32)
	ad2_title_lbl.add_theme_color_override("font_color", Color("#53d8fb"))
	ad2_vbox.add_child(ad2_title_lbl)
	var ad2_desc_lbl = Label.new()
	ad2_desc_lbl.text = "Fresh spring water keeps Buddy's coat shiny & energy high. Stock up today!"
	ad2_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ad2_desc_lbl.add_theme_font_size_override("font_size", 24)
	ad2_desc_lbl.add_theme_color_override("font_color", Color.WHITE)
	ad2_vbox.add_child(ad2_desc_lbl)

	# Ad 3 — Bundle / value promotion
	var ad3 = PanelContainer.new()
	ad3.name = "AdPanel3"
	left_col.add_child(ad3)
	var ad3_vbox = VBoxContainer.new()
	ad3_vbox.add_theme_constant_override("separation", 4)
	ad3.add_child(ad3_vbox)
	var ad3_title_lbl = Label.new()
	ad3_title_lbl.text = "📦 BUNDLE & SAVE 15%"
	ad3_title_lbl.add_theme_font_override("font", UITheme.get_pixel_font())
	ad3_title_lbl.add_theme_font_size_override("font_size", 32)
	ad3_title_lbl.add_theme_color_override("font_color", Color("#ffa34d"))
	ad3_vbox.add_child(ad3_title_lbl)
	var ad3_desc_lbl = Label.new()
	ad3_desc_lbl.text = "The Care Bundle packs 2x Kibble + 2x Water — that's a full 10-day supply for less!"
	ad3_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ad3_desc_lbl.add_theme_font_size_override("font_size", 24)
	ad3_desc_lbl.add_theme_color_override("font_color", Color.WHITE)
	ad3_vbox.add_child(ad3_desc_lbl)

	# Ad 4 — Loyalty rewards promotion
	var ad4 = PanelContainer.new()
	ad4.name = "AdPanel4"
	left_col.add_child(ad4)
	var ad4_vbox = VBoxContainer.new()
	ad4_vbox.add_theme_constant_override("separation", 4)
	ad4.add_child(ad4_vbox)
	var ad4_title_lbl = Label.new()
	ad4_title_lbl.text = "🌟 LOYALTY REWARDS"
	ad4_title_lbl.add_theme_font_override("font", UITheme.get_pixel_font())
	ad4_title_lbl.add_theme_font_size_override("font_size", 32)
	ad4_title_lbl.add_theme_color_override("font_color", UIColors.BTN_GREEN)
	ad4_vbox.add_child(ad4_title_lbl)
	var ad4_desc_lbl = Label.new()
	ad4_desc_lbl.text = "Every dollar spent earns Buddy Points! Redeem them for a FREE grooming kit."
	ad4_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ad4_desc_lbl.add_theme_font_size_override("font_size", 24)
	ad4_desc_lbl.add_theme_color_override("font_color", Color.WHITE)
	ad4_vbox.add_child(ad4_desc_lbl)

	# ── Center Column: Item Shelves ────────────────────────────────────────────
	var center_col = VBoxContainer.new()
	center_col.name = "CenterCol"
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.add_theme_constant_override("separation", 10)
	columns.add_child(center_col)

	var shelves_title = Label.new()
	shelves_title.text = "STORE ITEMS"
	shelves_title.add_theme_font_override("font", UITheme.get_pixel_font())
	shelves_title.add_theme_font_size_override("font_size", 32)
	shelves_title.add_theme_color_override("font_color", UITheme.CLR_INK)
	center_col.add_child(shelves_title)

	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_col.add_child(scroll)

	var shelves_vbox = VBoxContainer.new()
	shelves_vbox.name = "ShelvesVBox"
	shelves_vbox.add_theme_constant_override("separation", 12)
	shelves_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(shelves_vbox)

	# Item Card 1: Dog Food
	var food_card = PanelContainer.new()
	food_card.name = "FoodCard"
	shelves_vbox.add_child(food_card)
	_build_item_card(food_card, "food")

	# Item Card 2: Water
	var water_card = PanelContainer.new()
	water_card.name = "WaterCard"
	shelves_vbox.add_child(water_card)
	_build_item_card(water_card, "water")

	# Item Card 3: Prescription
	presc_card = PanelContainer.new()
	presc_card.name = "PrescCard"
	shelves_vbox.add_child(presc_card)
	_build_item_card(presc_card, "prescription")

	# Item Card 4: Care Bundle
	var bundle_card = PanelContainer.new()
	bundle_card.name = "BundleCard"
	shelves_vbox.add_child(bundle_card)
	_build_item_card(bundle_card, "bundle")

	# Item Card 5: Grooming Kit (cosmetic — deducts money, adds style!)
	var grooming_card = PanelContainer.new()
	grooming_card.name = "GroomingCard"
	shelves_vbox.add_child(grooming_card)
	_build_item_card(grooming_card, "grooming")

	# Item Card 6: Chew Toy (cosmetic — keeps Buddy entertained)
	toy_card = PanelContainer.new()
	toy_card.name = "ToyCard"
	shelves_vbox.add_child(toy_card)
	_build_item_card(toy_card, "toy")

	# ── Right Column: Shopping Cart & Checkout ──────────────────────────────────
	var right_col = VBoxContainer.new()
	right_col.name = "RightCol"
	right_col.custom_minimum_size = Vector2(400, 0)
	right_col.add_theme_constant_override("separation", 10)
	columns.add_child(right_col)

	var cart_title = Label.new()
	cart_title.text = "SHOPPING CART"
	cart_title.add_theme_font_override("font", UITheme.get_pixel_font())
	cart_title.add_theme_font_size_override("font_size", 32)
	cart_title.add_theme_color_override("font_color", UITheme.CLR_INK)
	right_col.add_child(cart_title)

	var cart_card = PanelContainer.new()
	cart_card.name = "CartCard"
	cart_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(cart_card)

	var cart_vbox = VBoxContainer.new()
	cart_vbox.add_theme_constant_override("separation", 12)
	cart_card.add_child(cart_vbox)

	var cart_scroll = ScrollContainer.new()
	cart_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cart_vbox.add_child(cart_scroll)

	cart_items_list = VBoxContainer.new()
	cart_items_list.name = "CartList"
	cart_items_list.add_theme_constant_override("separation", 8)
	cart_scroll.add_child(cart_items_list)

	# Divider line
	var cart_divider = ColorRect.new()
	cart_divider.color = Color(UITheme.CLR_INK.r, UITheme.CLR_INK.g, UITheme.CLR_INK.b, 0.22)
	cart_divider.custom_minimum_size = Vector2(0, 3)
	cart_vbox.add_child(cart_divider)

	# Checkout details
	var totals_vbox = VBoxContainer.new()
	totals_vbox.add_theme_constant_override("separation", 4)
	cart_vbox.add_child(totals_vbox)

	funds_label = Label.new()
	funds_label.name = "FundsLabel"
	funds_label.text = "Your Cash: $0.00"
	funds_label.add_theme_font_size_override("font_size", 24)
	totals_vbox.add_child(funds_label)

	total_label = Label.new()
	total_label.name = "TotalLabel"
	total_label.text = "Total: $0.00"
	total_label.add_theme_font_override("font", UITheme.get_pixel_font())
	total_label.add_theme_font_size_override("font_size", 32)
	totals_vbox.add_child(total_label)

	# Purchase Button
	purchase_btn = Button.new()
	purchase_btn.name = "PurchaseBtn"
	purchase_btn.text = "CHECKOUT"
	purchase_btn.custom_minimum_size = Vector2(0, 64)
	cart_vbox.add_child(purchase_btn)
	purchase_btn.pressed.connect(_on_purchase_pressed)
	purchase_btn.add_theme_font_size_override("font_size", 32)

	# Clear Button
	clear_btn = Button.new()
	clear_btn.name = "ClearBtn"
	clear_btn.text = "Clear Cart"
	clear_btn.custom_minimum_size = Vector2(0, 54)
	cart_vbox.add_child(clear_btn)
	clear_btn.pressed.connect(func():
		food_cart_count = 0
		water_cart_count = 0
		bundle_cart_count = 0
		grooming_cart_count = 0
		toy_cart_count = 0
		Sfx.click()
		update_ui()
	)
	clear_btn.add_theme_font_size_override("font_size", 32)

	# ── Apply Styling via UITheme ──────────────────────────────────────────────
	# Recursive overlay theme styles default labels/buttons
	UITheme.apply_overlay_theme(self)
	
	# Specific component overrides (navy backgrounds instead of cream)
	UITheme.style_panel(main_panel)
	UITheme.style_card(sk_portrait_card)
	UITheme.style_card(speech_card)
	UITheme.style_card(cart_card)
	
	# Pixel button configurations
	UITheme.style_close_button(close_btn)
	UITheme.style_pixel_button_colored(purchase_btn, UIColors.BTN_GREEN)
	UITheme.style_pixel_button(clear_btn, true)
	
	UITheme.style_accent_card(food_card, UIColors.BTN_GREEN)
	UITheme.style_accent_card(water_card, UIColors.BAR_THIRST)
	UITheme.style_accent_card(presc_card, UIColors.BTN_RED)
	UITheme.style_accent_card(bundle_card, UITheme.CLR_GOLD)
	UITheme.style_accent_card(grooming_card, Color("#c97dd4"))  # soft purple for grooming
	UITheme.style_accent_card(toy_card, Color("#d4a017"))       # warm amber for toy

	# Style the advertisement panels with opaque, clearly-visible dark backgrounds
	var _ad_sb := func(bg_hex: String, bdr: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(bg_hex)
		s.border_color = bdr
		s.border_width_left = 6
		s.border_width_top = 2
		s.border_width_right = 2
		s.border_width_bottom = 3
		s.set_corner_radius_all(8)
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 12
		s.content_margin_bottom = 12
		return s
	deal_strip.add_theme_stylebox_override("panel", _ad_sb.call("#271e0c", Color("#ffd84d")))
	ad2.add_theme_stylebox_override("panel", _ad_sb.call("#0a1e2c", Color("#53d8fb")))
	ad3.add_theme_stylebox_override("panel", _ad_sb.call("#221508", Color("#ffa34d")))
	ad4.add_theme_stylebox_override("panel", _ad_sb.call("#0d2010", UIColors.BTN_GREEN))

	# Post-overlay fixes — re-assert colors that the recursive styler may have reset
	# Speech bubble: white text on dark navy card
	speech_label.add_theme_color_override("font_color", Color.WHITE)
	speech_label.add_theme_constant_override("shadow_offset_x", 0)
	speech_label.add_theme_constant_override("shadow_offset_y", 0)
	# Deal strip: remove drop-shadow, make description white for legibility
	deal_title_label.add_theme_constant_override("shadow_offset_x", 0)
	deal_title_label.add_theme_constant_override("shadow_offset_y", 0)
	deal_desc_label.add_theme_color_override("font_color", Color.WHITE)
	deal_desc_label.add_theme_constant_override("shadow_offset_x", 0)
	deal_desc_label.add_theme_constant_override("shadow_offset_y", 0)
	# Cart: funds_label must be light-coloured on the dark navy card background
	funds_label.add_theme_color_override("font_color", Color(0.65, 0.80, 1.0))
	funds_label.add_theme_constant_override("shadow_offset_x", 0)
	funds_label.add_theme_constant_override("shadow_offset_y", 0)
	
	# Prescription checkbox: matches character customization page checkbox style
	if presc_checkbox:
		presc_checkbox.add_theme_color_override("font_color", UITheme.CLR_CREAM_LT)
		presc_checkbox.add_theme_color_override("font_hover_color", Color.WHITE)
		presc_checkbox.add_theme_color_override("font_pressed_color", UITheme.CLR_CREAM_LT)
		presc_checkbox.add_theme_color_override("font_outline_color", UITheme.CLR_INK)
		presc_checkbox.add_theme_constant_override("outline_size", 6)
	# Ad panels: strip shadows from every label inside
	for ad_panel in [deal_strip, ad2, ad3, ad4]:
		for c in ad_panel.get_child(0).get_children():
			if c is Label:
				c.add_theme_constant_override("shadow_offset_x", 0)
				c.add_theme_constant_override("shadow_offset_y", 0)

	# Custom styling for item quantity buttons (overrides generic theme settings)
	# Colors: minus = red-tinted navy, count = neutral, plus = green, +5 = gold/amber
	var _qty_btn_sb := func(bg: Color, border: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bg
		s.border_color = border
		s.border_width_left = 2
		s.border_width_top = 2
		s.border_width_right = 2
		s.border_width_bottom = 4  # bottom-heavy for 3-D feel
		s.set_corner_radius_all(6)
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		s.anti_aliasing = false
		return s

	for card_name in ["FoodCard", "WaterCard", "BundleCard", "GroomingCard", "ToyCard"]:
		var card = shelves_vbox.get_node(card_name)
		var ctrl_hbox = card.get_child(0).get_child(2)
		if ctrl_hbox.get_child_count() >= 4:
			var minus = ctrl_hbox.get_child(0) as Button
			var plus  = ctrl_hbox.get_child(2) as Button
			var plus5 = ctrl_hbox.get_child(3) as Button
			# Minus: dark crimson background with bright red border
			minus.add_theme_stylebox_override("normal",   _qty_btn_sb.call(Color("#4a1a1a"), Color("#e05555")))
			minus.add_theme_stylebox_override("hover",    _qty_btn_sb.call(Color("#6b2020"), Color("#ff7070")))
			minus.add_theme_stylebox_override("pressed",  _qty_btn_sb.call(Color("#3a1010"), Color("#cc3333")))
			# Plus: dark green background with bright green border
			plus.add_theme_stylebox_override("normal",    _qty_btn_sb.call(Color("#0f3320"), Color("#4CAF50")))
			plus.add_theme_stylebox_override("hover",     _qty_btn_sb.call(Color("#1a4d2e"), Color("#66d472")))
			plus.add_theme_stylebox_override("pressed",   _qty_btn_sb.call(Color("#0a2416"), Color("#3a9640")))
			# +5: dark gold background with amber border
			plus5.add_theme_stylebox_override("normal",   _qty_btn_sb.call(Color("#3a2800"), Color("#f0c040")))
			plus5.add_theme_stylebox_override("hover",    _qty_btn_sb.call(Color("#573c00"), Color("#ffd84d")))
			plus5.add_theme_stylebox_override("pressed",  _qty_btn_sb.call(Color("#281c00"), Color("#c8a020")))
			# Re-assert large font size on all three
			minus.add_theme_font_size_override("font_size", 32)
			plus.add_theme_font_size_override("font_size",  32)
			plus5.add_theme_font_size_override("font_size", 32)
			# Font color: white for legibility on dark backgrounds
			minus.add_theme_color_override("font_color",         Color.WHITE)
			minus.add_theme_color_override("font_hover_color",   Color.WHITE)
			minus.add_theme_color_override("font_pressed_color", Color.WHITE)
			plus.add_theme_color_override("font_color",          Color.WHITE)
			plus.add_theme_color_override("font_hover_color",    Color.WHITE)
			plus.add_theme_color_override("font_pressed_color",  Color.WHITE)
			plus5.add_theme_color_override("font_color",         Color.WHITE)
			plus5.add_theme_color_override("font_hover_color",   Color.WHITE)
			plus5.add_theme_color_override("font_pressed_color", Color.WHITE)


# Helper function to construct structured item cards programmatically
func _build_item_card(card: PanelContainer, type: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# 1. Left side: Item Icon Tile
	var icon_color := UIColors.BTN_GREEN
	var emoji := "🍖"
	match type:
		"water":
			icon_color = UIColors.BAR_THIRST
			emoji = "💧"
		"prescription":
			icon_color = UIColors.BTN_RED
			emoji = "💊"
		"bundle":
			icon_color = UITheme.CLR_GOLD
			emoji = "📦"
		"grooming":
			icon_color = Color("#c97dd4")
			emoji = "🧼"
		"toy":
			icon_color = Color("#d4a017")
			emoji = "🧸"
			
	var icon_tile = UITheme.make_icon_tile(icon_color, 80)
	hbox.add_child(icon_tile)
	
	var emoji_lbl = Label.new()
	emoji_lbl.text = emoji
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji_lbl.add_theme_font_size_override("font_size", 48)
	icon_tile.add_child(emoji_lbl)

	# 2. Middle side: Title & Description & Pricing
	var mid_vbox = VBoxContainer.new()
	mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(mid_vbox)

	var title_hbox = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 10)
	mid_vbox.add_child(title_hbox)

	var title_lbl = Label.new()
	title_lbl.add_theme_font_override("font", UITheme.get_pixel_font())
	title_lbl.add_theme_font_size_override("font_size", 32)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_hbox.add_child(title_lbl)

	# Recommended label (different design: no background panel, no padding)
	var recom_badge = Label.new()
	recom_badge.name = "RecomLabel"
	recom_badge.text = "⭐ RECOMMENDED"
	recom_badge.add_theme_font_override("font", UITheme.get_pixel_font())
	recom_badge.add_theme_font_size_override("font_size", 24)
	recom_badge.add_theme_color_override("font_color", Color("#ffd071"))
	title_hbox.add_child(recom_badge)
	recom_badge.visible = false

	# Description text
	var desc_lbl = Label.new()
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 24)
	desc_lbl.add_theme_color_override("font_color", Color("#b2c2e0"))
	mid_vbox.add_child(desc_lbl)

	# Pricing details
	var price_hbox = HBoxContainer.new()
	price_hbox.add_theme_constant_override("separation", 14)
	mid_vbox.add_child(price_hbox)

	var price_lbl = Label.new()
	price_lbl.add_theme_font_override("font", UITheme.get_pixel_font())
	price_lbl.add_theme_font_size_override("font_size", 32)
	price_lbl.add_theme_color_override("font_color", UIColors.BTN_GREEN)
	price_hbox.add_child(price_lbl)

	var owned_lbl = Label.new()
	owned_lbl.add_theme_font_size_override("font_size", 24)
	owned_lbl.add_theme_color_override("font_color", Color("#8e9fb8"))
	price_hbox.add_child(owned_lbl)

	# Match parameters — set text, assign node references
	match type:
		"food":
			title_lbl.text = "Premium Dog Kibble"
			desc_lbl.text = "Delicious food to keep your pet energetic. Lasts 5 days."
			food_owned_label = owned_lbl
			food_recom_badge = recom_badge
			food_price_label = price_lbl
		"water":
			title_lbl.text = "Fresh Spring Water"
			desc_lbl.text = "Clean, filtered water to satisfy your pet's thirst. Lasts 5 days."
			water_owned_label = owned_lbl
			water_recom_badge = recom_badge
			water_price_label = price_lbl
		"prescription":
			title_lbl.text = "Vet Prescription Medicine"
			desc_lbl.text = "Required medication to treat illness and cure infections."
			presc_owned_label = owned_lbl
			presc_price_label = price_lbl
		"bundle":
			title_lbl.text = "Buddy Care Bundle"
			desc_lbl.text = "Week's supply: 2x Kibble + 2x Water (10 days total) at 15% off!"
			bundle_price_label = price_lbl
		"grooming":
			# Cosmetic item — deducts money but no major stat effect
			title_lbl.text = "Deluxe Grooming Kit"
			desc_lbl.text = "Pamper Buddy with a full brush, shampoo & nail trim session! 🛁"
			recom_badge.visible = false
			owned_lbl.text = "Cosmetic"
			owned_lbl.add_theme_color_override("font_color", Color("#c97dd4"))
			price_lbl.text = "$" + str(GROOMING_PRICE)
			grooming_price_label = price_lbl
		"toy":
			# Cosmetic item — keeps Buddy entertained
			title_lbl.text = "Squeaky Chew Toy"
			desc_lbl.text = "A durable rubber toy to keep Buddy busy and happy all day! 🦴"
			recom_badge.visible = false
			owned_lbl.text = "Cosmetic"
			owned_lbl.add_theme_color_override("font_color", Color("#d4a017"))
			price_lbl.text = "$" + str(TOY_PRICE)
			toy_price_label = price_lbl

	# 3. Right side: Quantity Controls
	var ctrl_hbox = HBoxContainer.new()
	ctrl_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ctrl_hbox.add_theme_constant_override("separation", 10)
	hbox.add_child(ctrl_hbox)

	if type == "prescription":
		# Medication uses checkmark toggle
		presc_checkbox = CheckBox.new()
		presc_checkbox.text = "Select"
		presc_checkbox.focus_mode = Control.FOCUS_NONE
		presc_checkbox.add_theme_font_size_override("font_size", 24)
		ctrl_hbox.add_child(presc_checkbox)
		presc_checkbox.toggled.connect(_on_prescription_toggled)
	else:
		# Quantities controls
		var minus_btn = Button.new()
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(64, 64)
		minus_btn.focus_mode = Control.FOCUS_NONE
		minus_btn.add_theme_font_size_override("font_size", 32)
		ctrl_hbox.add_child(minus_btn)

		var count_lbl = Label.new()
		count_lbl.text = "0"
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.custom_minimum_size = Vector2(48, 0)
		count_lbl.add_theme_font_override("font", UITheme.get_pixel_font())
		count_lbl.add_theme_font_size_override("font_size", 32)
		count_lbl.add_theme_color_override("font_color", Color.WHITE)
		ctrl_hbox.add_child(count_lbl)

		var plus_btn = Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(64, 64)
		plus_btn.focus_mode = Control.FOCUS_NONE
		plus_btn.add_theme_font_size_override("font_size", 32)
		ctrl_hbox.add_child(plus_btn)

		var plus5_btn = Button.new()
		plus5_btn.text = "+5"
		plus5_btn.custom_minimum_size = Vector2(80, 64)
		plus5_btn.focus_mode = Control.FOCUS_NONE
		plus5_btn.add_theme_font_size_override("font_size", 32)
		ctrl_hbox.add_child(plus5_btn)

		# Bind control clicks for each item type
		match type:
			"food":
				food_count_label = count_lbl
				minus_btn.pressed.connect(_on_food_minus_pressed)
				plus_btn.pressed.connect(_on_food_plus_pressed)
				plus5_btn.pressed.connect(func():
					food_cart_count += 5
					Sfx.click()
					update_ui()
				)
			"water":
				water_count_label = count_lbl
				minus_btn.pressed.connect(_on_water_minus_pressed)
				plus_btn.pressed.connect(_on_water_plus_pressed)
				plus5_btn.pressed.connect(func():
					water_cart_count += 5
					Sfx.click()
					update_ui()
				)
			"bundle":
				bundle_count_label = count_lbl
				minus_btn.pressed.connect(func():
					if bundle_cart_count > 0:
						bundle_cart_count -= 1
						Sfx.click()
						update_ui()
				)
				plus_btn.pressed.connect(func():
					bundle_cart_count += 1
					Sfx.click()
					update_ui()
				)
				plus5_btn.pressed.connect(func():
					bundle_cart_count += 5
					Sfx.click()
					update_ui()
				)
			"grooming":
				grooming_count_label = count_lbl
				minus_btn.pressed.connect(func():
					if grooming_cart_count > 0:
						grooming_cart_count -= 1
						Sfx.click()
						update_ui()
				)
				plus_btn.pressed.connect(func():
					grooming_cart_count += 1
					Sfx.click()
					update_ui()
				)
				plus5_btn.pressed.connect(func():
					grooming_cart_count += 5
					Sfx.click()
					update_ui()
				)
			"toy":
				toy_count_label = count_lbl
				minus_btn.pressed.connect(func():
					if toy_cart_count > 0:
						toy_cart_count -= 1
						Sfx.click()
						update_ui()
				)
				plus_btn.pressed.connect(func():
					toy_cart_count += 1
					Sfx.click()
					update_ui()
				)
				plus5_btn.pressed.connect(func():
					toy_cart_count += 5
					Sfx.click()
					update_ui()
				)

# Choose Daily Deal randomly on shop open — only item-based discounts (Kibble / Water / Bundle).
# A gold " SALE" label with the original crossed-out price is shown via _update_price_display.
func _choose_daily_deal() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	# Three meaningful item deals only (0=Kibble, 1=Water, 2=Bundle)
	var choice = rng.randi_range(0, 2)
	
	# Reset to base pricing first
	food_price_current         = GameState.food_cost
	water_price_current        = GameState.water_cost
	prescription_price_current = GameState.medicine_cost
	bundle_price_current       = round((2 * GameState.food_cost + 2 * GameState.water_cost) * 0.85)
	
	match choice:
		0:  # 🍗 Kibble on sale — 20% off
			active_deal_title = "🍗 KIBBLE SALE — 20% OFF!"
			active_deal_desc  = "Premium Dog Kibble is discounted today only! Stock up & save."
			food_price_current = max(1, round(GameState.food_cost * 0.80))
		1:  # 💧 Water on sale — 20% off
			active_deal_title = "💧 WATER DEAL — 20% OFF!"
			active_deal_desc  = "Fresh Spring Water is cheaper today. Hydrate Buddy for less!"
			water_price_current = max(1, round(GameState.water_cost * 0.80))
		2:  # 📦 Bundle on sale — 25% off (stacks on top of the bundle's built-in 15% discount)
			active_deal_title = "📦 BUNDLE BLOWOUT — 25% OFF!"
			active_deal_desc  = "The Care Bundle is at its lowest price ever. Don't miss out!"
			bundle_price_current = max(1, round((2 * GameState.food_cost + 2 * GameState.water_cost) * 0.75))

# Helper to format and style prices dynamically
func _update_price_display(lbl: Label, current: int, base: int) -> void:
	if lbl == null: return
	if current < base:
		lbl.text = "$" + str(current) + " (Was $" + str(base) + ")"
		lbl.add_theme_color_override("font_color", UITheme.CLR_GOLD)
	else:
		lbl.text = "$" + str(current)
		lbl.add_theme_color_override("font_color", UIColors.BTN_GREEN)

# Refresh all UI dynamic stats, cart listings, and shopkeeper face reactions
func update_ui() -> void:
	# Counters
	if food_count_label:
		food_count_label.text = str(food_cart_count)
	if water_count_label:
		water_count_label.text = str(water_cart_count)
	if bundle_count_label:
		bundle_count_label.text = str(bundle_cart_count)

	# Pricing labels
	_update_price_display(food_price_label, food_price_current, GameState.food_cost)
	_update_price_display(water_price_label, water_price_current, GameState.water_cost)
	_update_price_display(bundle_price_label, bundle_price_current, round((2 * GameState.food_cost + 2 * GameState.water_cost) * 0.85))

	if presc_price_label:
		presc_price_label.text = "$" + str(prescription_price_current)

	# Owned inventory + Recommended stock alert indicators
	if food_owned_label:
		food_owned_label.text = "Owned: " + str(GameState.food) + " days"
		if GameState.food < 5:
			food_owned_label.add_theme_color_override("font_color", CLR_RED)
			food_recom_badge.visible = true
		else:
			food_owned_label.add_theme_color_override("font_color", Color("#8e9fb8"))
			food_recom_badge.visible = false

	if water_owned_label:
		water_owned_label.text = "Owned: " + str(GameState.water) + " days"
		if GameState.water < 5:
			water_owned_label.add_theme_color_override("font_color", CLR_RED)
			water_recom_badge.visible = true
		else:
			water_owned_label.add_theme_color_override("font_color", Color("#8e9fb8"))
			water_recom_badge.visible = false

	if presc_owned_label:
		if GameState.medication != "none":
			presc_owned_label.text = "Active course: " + GameState.medication
		else:
			presc_owned_label.text = "No active prescription"

	# Highlight prescription card border dynamically if selected
	if presc_card:
		var sb = presc_card.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			var new_sb = sb.duplicate() as StyleBoxFlat
			if prescription_selected:
				new_sb.border_color = UITheme.CLR_GOLD
				new_sb.border_width_left = 6
			else:
				new_sb.border_color = Color(UIColors.BTN_RED.r, UIColors.BTN_RED.g, UIColors.BTN_RED.b, 0.22)
				new_sb.border_width_left = 3
			presc_card.add_theme_stylebox_override("panel", new_sb)

	# Update cosmetic item count labels
	if grooming_count_label:
		grooming_count_label.text = str(grooming_cart_count)
	if toy_count_label:
		toy_count_label.text = str(toy_cart_count)

	# Calculate checkout cost (includes cosmetic items)
	var total = (food_cart_count * food_price_current) \
		+ (water_cart_count * water_price_current) \
		+ (bundle_cart_count * bundle_price_current) \
		+ (grooming_cart_count * GROOMING_PRICE) \
		+ (toy_cart_count * TOY_PRICE)
	if prescription_selected:
		total += prescription_price_current

	# Populate Shopping Cart contents dynamically
	for child in cart_items_list.get_children():
		child.queue_free()

	var added_any := false
	if food_cart_count > 0:
		_add_cart_row("Dog Kibble", food_cart_count, food_cart_count * food_price_current)
		added_any = true
	if water_cart_count > 0:
		_add_cart_row("Spring Water", water_cart_count, water_cart_count * water_price_current)
		added_any = true
	if bundle_cart_count > 0:
		_add_cart_row("Care Bundle", bundle_cart_count, bundle_cart_count * bundle_price_current)
		added_any = true
	if prescription_selected:
		_add_cart_row("Prescription", 1, prescription_price_current)
		added_any = true
	if grooming_cart_count > 0:
		_add_cart_row("Grooming Kit", grooming_cart_count, grooming_cart_count * GROOMING_PRICE)
		added_any = true
	if toy_cart_count > 0:
		_add_cart_row("Chew Toy", toy_cart_count, toy_cart_count * TOY_PRICE)
		added_any = true

	if not added_any:
		var empty_lbl = Label.new()
		empty_lbl.text = "Your cart is empty."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color("#8fa8c8"))
		empty_lbl.add_theme_font_size_override("font_size", 24)
		cart_items_list.add_child(empty_lbl)

	# Set totals text
	total_label.text = "Total: $" + str(total)
	funds_label.text = "Your Cash: $" + str(snappedf(GameState.money, 0.01))

	# Enable/Disable checkout and change Shopkeeper reactions
	if total <= GameState.money:
		total_label.add_theme_color_override("font_color", CLR_GREEN)
		purchase_btn.disabled = (total == 0)
		purchase_btn.text = "CONFIRM PURCHASE"
		if total == 0:
			shopkeeper_avatar.texture = BBPix.avatar_texture(42, "neutral")
			speech_label.text = "Welcome! Need anything for your pet today?"
		else:
			shopkeeper_avatar.texture = BBPix.avatar_texture(42, "happy")
			if prescription_selected:
				speech_label.text = "Please make sure your pet finishes the full prescription course!"
			elif bundle_cart_count > 0:
				speech_label.text = "The Care Bundle is our best deal! Smart shopping!"
			else:
				speech_label.text = "Nice selections! Your buddy will thank you."
	else:
		total_label.add_theme_color_override("font_color", CLR_RED)
		purchase_btn.disabled = true
		purchase_btn.text = "INSUFFICIENT CASH"
		shopkeeper_avatar.texture = BBPix.avatar_texture(42, "neutral")
		speech_label.text = "Oh... you don't seem to have enough cash on hand."

# Helper to populate dynamic rows in cart panel
func _add_cart_row(item_name: String, qty: int, cost: int) -> void:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_lbl = Label.new()
	name_lbl.text = item_name + " x" + str(qty)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(name_lbl)
	
	var cost_lbl = Label.new()
	cost_lbl.text = "$" + str(cost)
	cost_lbl.add_theme_font_override("font", UITheme.get_pixel_font())
	cost_lbl.add_theme_font_size_override("font_size", 24)
	cost_lbl.add_theme_color_override("font_color", UITheme.CLR_GOLD)
	row.add_child(cost_lbl)
	
	cart_items_list.add_child(row)

# Show shop menu with deals and reactive states
func show_shop() -> void:
	if visible:
		return
	GameState.store_visit_count += 1
	GameState.check_achievements()
	
	# Reset all cart counts on open
	food_cart_count    = 0
	water_cart_count   = 0
	bundle_cart_count  = 0
	grooming_cart_count = 0
	toy_cart_count     = 0
	
	# Seed-random choice of daily deal
	_choose_daily_deal()
	deal_title_label.text = active_deal_title
	deal_desc_label.text = active_deal_desc

	# Determine prescription availability
	prescription_available = GameState.has_prescription and GameState.medication != "Antibiotics (5 days)"
	if presc_card:
		presc_card.visible = prescription_available
	if toy_card:
		toy_card.visible = not prescription_available
	
	if prescription_available:
		prescription_selected = true
		if presc_checkbox:
			presc_checkbox.button_pressed = true
	else:
		prescription_selected = false
		if presc_checkbox:
			presc_checkbox.button_pressed = false
			
	# Initialize shopkeeper portrait
	if shopkeeper_avatar:
		# Use seed 42 for a cozy looking shopkeeper character
		shopkeeper_avatar.texture = BBPix.avatar_texture(42, "neutral")

	update_ui()
	visible = true
	get_tree().paused = true

# Symmetric exit method
func hide_shop() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	shop_closed.emit()

func _on_close_btn_pressed() -> void:
	Sfx.click()
	visible = false
	get_tree().paused = false
	shop_closed.emit()

# Plus / Minus handlers
func _on_food_plus_pressed() -> void:
	food_cart_count += 1
	Sfx.click()
	update_ui()

func _on_food_minus_pressed() -> void:
	if food_cart_count > 0:
		food_cart_count -= 1
		Sfx.click()
		update_ui()

func _on_water_plus_pressed() -> void:
	water_cart_count += 1
	Sfx.click()
	update_ui()

func _on_water_minus_pressed() -> void:
	if water_cart_count > 0:
		water_cart_count -= 1
		Sfx.click()
		update_ui()

func _on_prescription_toggled(toggled_on: bool) -> void:
	prescription_selected = toggled_on
	Sfx.click()
	update_ui()

# Perform checkout and trigger animations
func _on_purchase_pressed() -> void:
	var total = (food_cart_count * food_price_current) \
		+ (water_cart_count * water_price_current) \
		+ (bundle_cart_count * bundle_price_current) \
		+ (grooming_cart_count * GROOMING_PRICE) \
		+ (toy_cart_count * TOY_PRICE)
	if prescription_selected:
		total += prescription_price_current
		
	if total == 0:
		return
		
	if GameState.money >= total:
		# Block purchase button
		purchase_btn.disabled = true
		
		# Play happy success pitch
		Sfx.click(1.2)
		
		# Trigger visual flash & punch scale tween
		var tw = create_tween().set_parallel(true)
		tw.tween_property(main_panel, "scale", Vector2(1.02, 1.02), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(main_panel, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.1)
		
		var success := true
		
		# Process payments for real items
		var food_spend     = food_cart_count    * food_price_current
		var water_spend    = water_cart_count   * water_price_current
		var bundle_spend   = bundle_cart_count  * bundle_price_current
		var cosmetic_spend = (grooming_cart_count * GROOMING_PRICE) + (toy_cart_count * TOY_PRICE)
		
		if food_spend > 0:
			success = GameState.spend_money(food_spend, "Food")
		if success and water_spend > 0:
			success = GameState.spend_money(water_spend, "Food")
		if success and bundle_spend > 0:
			success = GameState.spend_money(bundle_spend, "Food")
		# Cosmetic items: just deduct money, no stat changes
		if success and cosmetic_spend > 0:
			success = GameState.spend_money(cosmetic_spend, "Food")
		if success and prescription_selected:
			success = GameState.spend_money(prescription_price_current, "Vet")
			if success:
				GameState.times_medicated += 1
				GameState.medication = "Antibiotics (5 days)"
				GameState.has_prescription = false
				var dog = get_tree().get_first_node_in_group("dog")
				if dog:
					dog.health = min(100, dog.health + 40)
					
		if success:
			# Update supplies inventory
			GameState.food += (food_cart_count * 5) + (bundle_cart_count * 10)
			GameState.water += (water_cart_count * 5) + (bundle_cart_count * 10)
			
			# Smile!
			shopkeeper_avatar.texture = BBPix.avatar_texture(42, "happy")
			speech_label.text = "Thank you so much! Your buddy is going to love these!"
			
			# Tween back and close
			var tw_back = create_tween().set_parallel(true)
			tw_back.tween_property(main_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_back.tween_property(main_panel, "modulate", Color.WHITE, 0.25)
			
			await get_tree().create_timer(0.6).timeout
			
			visible = false
			get_tree().paused = false
			shop_closed.emit()
		else:
			# Rollback
			purchase_btn.disabled = false
			main_panel.scale = Vector2.ONE
			main_panel.modulate = Color.WHITE
			shopkeeper_avatar.texture = BBPix.avatar_texture(42, "angry")
			speech_label.text = "Wait, transaction got canceled..."
	else:
		# Insufficient funds click
		Sfx.click(0.8)
		
		# Trigger checkout shake tween
		var original_pos = main_panel.position
		var tw_shake = create_tween()
		for i in range(4):
			var offset_x = randf_range(-10, 10)
			var offset_y = randf_range(-6, 6)
			tw_shake.tween_property(main_panel, "position", original_pos + Vector2(offset_x, offset_y), 0.05)
		tw_shake.tween_property(main_panel, "position", original_pos, 0.05)
		
		shopkeeper_avatar.texture = BBPix.avatar_texture(42, "angry")
		speech_label.text = "Oh, you don't have enough cash for all this!"
