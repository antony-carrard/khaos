extends GdUnitTestSuite

# NetworkSync.find_rejoin_seat(): which seat a returning player takes back,
# and the NetworkManager resume lobby built on it.


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


# NetworkManager's resume lobby: seating by the saved game's names.

func after_test() -> void:
	NetworkManager.resume_names.clear()
	NetworkManager.resume_seats.clear()


func test_resume_lobby_seats_the_host_by_name() -> void:
	assert_bool(NetworkManager.open_resume_lobby("Bob", NAMES)).is_true()
	assert_dict(NetworkManager.resume_seats).is_equal({1: 1})


func test_resume_lobby_refuses_a_host_not_in_the_save() -> void:
	assert_bool(NetworkManager.open_resume_lobby("Dave", NAMES)).is_false()
	assert_array(NetworkManager.resume_names).is_empty()


func test_resume_lobby_hands_a_joiner_its_free_seat() -> void:
	NetworkManager.open_resume_lobby("Alice", NAMES)
	assert_int(NetworkManager._free_resume_seat("Carol")).is_equal(2)


func test_resume_lobby_refuses_a_taken_seat() -> void:
	NetworkManager.open_resume_lobby("Alice", NAMES)
	assert_int(NetworkManager._free_resume_seat("Alice")).is_equal(-1)


# Two windows on one machine share the saved name, so duplicates happen in testing.
func test_resume_lobby_seats_a_duplicate_name_in_the_other_seat() -> void:
	var names: Array[String] = ["Antony", "Antony"]
	NetworkManager.open_resume_lobby("Antony", names)
	assert_int(NetworkManager._free_resume_seat("Antony")).is_equal(1)
