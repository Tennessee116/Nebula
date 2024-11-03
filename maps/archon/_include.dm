#if !defined(USING_MAP_DATUM)

	#include "area.dm"
	#include "turf.dm"

	#include "area/archon_3.dm"

	#include "obj/floor_decal.dm"
	#include "obj/structure.dm"

	#include "archon_1.dmm"
	#include "archon_2.dmm"
	#include "archon_3.dmm"

 	#define USING_MAP_DATUM /datum/map/archon

#elif !defined(MAP_OVERRIDE)
	#warn A map has already been included, ignoring Archon
#endif