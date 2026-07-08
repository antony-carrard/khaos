class_name BicephallesGod
extends God

func _init():
	super("Bicéphallès", "res://assets/gods/bicéphallès.jpg")

	powers.append(ExtraActionPower.new())
	powers.append(SecondHarvestPower.new())
