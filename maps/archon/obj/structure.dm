/obj/structure/container
	name			= "unmarked container"
	icon			= 'maps/archon/obj/container.dmi'

/obj/structure/container/grey
	desc			= "It's a nondescript, grey, unmarked container. I wonder what's inside?"
	icon_state		= "greyunmarked"
	density			= TRUE
	layer			= ABOVE_HUMAN_LAYER
	parts_amount	= 6
	parts_type		= /obj/item/stack/material/strut

/obj/structure/container/blue
	desc			= "It's a nondescript, blue, unmarked container. I wonder if there's anything inside?"
	icon_state		= "blueunmarked"

/obj/structure/container/archon
	name			= "labeled container"
	desc			= "It's a sturdier brown container tagged by the Archon's engineering department. Used to hold materials."
	icon_state		= "brownengi"

/obj/structure/crane
	name			= "crane hook"
	icon			= 'maps/archon/obj/structure.dmi'
	desc			= "A cargo crane hook, meant for attaching to cargo containers in order to lift them."
	icon_state		= "hook"
	density			= FALSE
	layer			= ABOVE_HUMAN_LAYER
	parts_amount	= 2
	parts_type		= /obj/item/stack/material/strut

/obj/structure/crane/cable
	name		= "crane cable"
	desc		= "Cables which hold up the crane and cargo below."
	icon_state	= "cable"

/obj/structure/platform
	name					= "platform"
	icon					= 'structure.dmi'
	icon_state				= "platform"
	anchored				= TRUE
	density					= FALSE
	layer					= BELOW_OBJ_LAYER
	opacity					= FALSE
	tool_interaction_flags	= TOOL_INTERACTION_DECONSTRUCT
	parts_type 				= /obj/item/stack/material/strut

/obj/structure/platform/ladder
	name 		= "ladder"
	icon_state	= "ladder"