extends Area2D

# Attach this to an Area2D shaped around the house interior.
# The player's body entering flips GameState.is_in_house to true;
# leaving flips it back to false. Used to gate the B "sim day" key
# and for any other in-house-only features.

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		GameState.is_in_house = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		GameState.is_in_house = false
