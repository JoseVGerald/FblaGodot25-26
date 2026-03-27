# NotificationCenter.gd
# Autoload singleton that stores all game notifications for player review.
# Notification types:
#   TYPE_EVENT       — pet/world events (info only, not clickable)
#   TYPE_ACHIEVEMENT — achievement unlocked (click opens achievements panel)
#   TYPE_WARNING     — emergencies like low health, out of food/water

extends Node

# ── Notification type enum ───────────────────────────────────────────────────
enum NotifType { EVENT, ACHIEVEMENT, WARNING }

# ── Storage ──────────────────────────────────────────────────────────────────
# Each entry is a Dictionary:
#   { type: NotifType, message: String, timestamp_day: int, read: bool }
var notifications: Array = []
var has_unread_warning: bool = false
var has_unread: bool = false

# ── Signals ───────────────────────────────────────────────────────────────────
signal notification_added(entry: Dictionary)
signal badge_state_changed

# ══════════════════════════════════════════════════════════════════════════════
#  PUBLIC API
# ══════════════════════════════════════════════════════════════════════════════

## Add a new notification entry and notify listeners.
## Called by bottom_hud signal handlers and simulation warning router.
func add_notification(type: NotifType, message: String) -> void:
	var entry := {
		"type": type,
		"message": message,
		"timestamp_day": GameState.current_day,
		"read": false
	}
	notifications.append(entry)
	has_unread = true
	if type == NotifType.WARNING:
		has_unread_warning = true
	notification_added.emit(entry)
	badge_state_changed.emit()

## Mark all notifications as read. Called when the player opens the panel.
## Clears the badge/pulse animation via badge_state_changed signal.
func mark_all_read() -> void:
	for n in notifications:
		n.read = true
	has_unread = false
	has_unread_warning = false
	badge_state_changed.emit()

## Remove a single notification entry.
func remove_notification(entry: Dictionary) -> void:
	var idx = notifications.find(entry)
	if idx != -1:
		notifications.remove_at(idx)
		badge_state_changed.emit()

## Clear the entire history.
func clear_all() -> void:
	notifications.clear()
	has_unread = false
	has_unread_warning = false
	badge_state_changed.emit()
