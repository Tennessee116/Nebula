/// Not an area but links the z levels together.
/obj/abstract/map_data/archon
	height	= 3

/area/station
	secure = TRUE
	holomap_color = HOLOMAP_AREACOLOR_CREW

/area/station/command
	holomap_color = HOLOMAP_AREACOLOR_COMMAND

///The bridge gets renamed after init for holopad simplicity.
/area/station/command/bridge
	name = "\improper Bridge"
	icon_state = "bridge"
	req_access = list(access_bridge)

/area/station/command/bridge/Initialize()
	. = ..()
	name = "\improper [global.using_map.station_short] Bridge"

/area/station/command/captain
	name = "\improper Captain's Office"
	icon_state = "captain"
	sound_env = MEDIUM_SOFTFLOOR
	req_access = list(access_captain)

/area/station/command/captain/bedroom
	name = "\improper Captain's Quarters"