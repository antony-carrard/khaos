class_name BicephallesGod
extends God

func _init():
	super("Bicéphallès", "res://assets/gods/bicéphallès.jpg",
		"Action bonus", "1 action bonus à chaque tour (4 actions au lieu de 3)")

	total_actions = 4

	# minor/major intentionally null — rules.md gives Bicéphallès a bonus-harvest
	# minor and a double-village major; both are content-pass work.
