class_name ExtraActionPower
extends InstantGodPower

## Bicéphallès minor power — "4 actions au prochain tour".
## Stubbed to a no-op: its bonus-action state doesn't exist anywhere in the
## current codebase, and the power itself isn't in the rewritten rules.md.
## Keeping the stub (rather than removing the power) preserves the fervor/
## action cost so the god's behavior doesn't silently change mid-refactor.

func _init():
	super("Actions supplémentaires", "4 actions au prochain tour", 2)


func apply(_board_manager: Node3D) -> void:
	# TODO: bonus-action effect removed pending a future rules-content pass.
	pass
