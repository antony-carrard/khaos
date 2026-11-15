extends GdUnitTestSuite

# NetworkSync.find_rejoin_seat(): which seat a returning player takes back.


const NAMES: Array[String] = ["Alice", "Bob", "Carol"]


func test_matches_the_absent_seat_with_that_name() -> void:
	assert_int(NetworkSync.find_rejoin_seat("Bob", NAMES, [1])).is_equal(1)


func test_refuses_a_name_whose_seat_is_still_connected() -> void:
	assert_int(NetworkSync.find_rejoin_seat("Alice", NAMES, [1])).is_equal(-1)


func test_refuses_an_unknown_name() -> void:
	assert_int(NetworkSync.find_rejoin_seat("Dave", NAMES, [0, 1, 2])).is_equal(-1)


func test_refuses_when_nobody_is_absent() -> void:
	assert_int(NetworkSync.find_rejoin_seat("Bob", NAMES, [])).is_equal(-1)


# Two windows on one machine share the saved name, so duplicates happen in testing.
func test_duplicate_names_only_match_the_absent_one() -> void:
	var names: Array[String] = ["Antony", "Antony"]
	assert_int(NetworkSync.find_rejoin_seat("Antony", names, [1])).is_equal(1)


func test_duplicate_names_both_absent_take_the_lowest_seat() -> void:
	var names: Array[String] = ["Antony", "Antony"]
	assert_int(NetworkSync.find_rejoin_seat("Antony", names, [1, 0])).is_equal(0)
