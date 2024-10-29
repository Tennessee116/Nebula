/datum/map/archon
	name		= "Archon"
	full_name	= "NanoTrasen Contractor Vessel Archon"
	path		= "archon"

	station_name	= "NanoTrasen Contractor Vessel Archon"
	station_short	= "NTCV Archon"
	dock_name		= "NTSS Moloch"
	boss_name		= "NanoTrasen Head Office"
	boss_short		= "Head Office"
	company_name	= "NanoTrasen Corporation"
	company_short	= "NanoTrasen"
	ground_noun		= "floor"

	//lobby_screens = list('maps/archon/lobby/bosnian.png')
	overmap_ids = list(OVERMAP_ID_SPACE)
	num_exoplanets = 2
	welcome_sound = 'sound/AI/welcome.ogg'
	emergency_shuttle_leaving_dock = "The automated rescue shuttle is now departing and will arrive at its destination in %ETA%."
	emergency_shuttle_called_message = "An emergency evacuation has been declared. An automated rescue shuttle will arrive in %ETA%"
	emergency_shuttle_recall_message = "The emergency evacuation has been cancelled. The automated rescue shuttle has been recalled."
	evac_controller_type = /datum/evacuation_controller/shuttle

	starting_money = 1000
	department_money = 1000

	radiation_detected_message = "High levels of radiation detected. Please move to a shielded area until the radiation has passed."
	default_telecomms_channels = list(COMMON_FREQUENCY_DATA)

/datum/map/archon/New()
	. = ..()
	emergency_shuttle_leaving_dock = "The automated rescue shuttle is now departing and will arrive at [dock_name] in %ETA%."
	emergency_shuttle_called_message = "An emergency evacuation has been declared. An automated [company_short] emergency shuttle will arrive in %ETA%"

/datum/map/archon/get_map_info()
	return "You're aboard the <b>[station_short]</b>, a contractor vessel affiliated with the [company_short] and the Sol United Authority. \
	No meaningful authorities can claim the planets and resources in this uncharted sector, so their exploitation is entirely up to you - mine, poach and deforest all you want."
