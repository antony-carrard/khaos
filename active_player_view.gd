extends Node
class_name ActivePlayerView

## Signal bridge between the current player and the UI.
## The UI connects to this node once at startup and never rewires on player switch.
## bind() handles disconnecting old player and connecting the new one.

signal resources_changed(amount: int)
signal fervor_changed(amount: int)
signal glory_changed(amount: int)
signal actions_changed(amount: int)
signal power_used(power_type: int)
signal player_changed(player: Player)   # fires on every bind() — triggers UI rebuild

var current_player: Player = null


func bind(player: Player) -> void:
	if current_player:
		current_player.resources_changed.disconnect(resources_changed.emit)
		current_player.fervor_changed.disconnect(fervor_changed.emit)
		current_player.glory_changed.disconnect(glory_changed.emit)
		current_player.actions_changed.disconnect(actions_changed.emit)
		current_player.power_used.disconnect(power_used.emit)
	current_player = player
	if player:
		player.resources_changed.connect(resources_changed.emit)
		player.fervor_changed.connect(fervor_changed.emit)
		player.glory_changed.connect(glory_changed.emit)
		player.actions_changed.connect(actions_changed.emit)
		player.power_used.connect(power_used.emit)
		# Immediately push current values to refresh all UI
		resources_changed.emit(player.resources)
		fervor_changed.emit(player.fervor)
		glory_changed.emit(player.glory)
		actions_changed.emit(player.actions_remaining)
		player_changed.emit(player)
