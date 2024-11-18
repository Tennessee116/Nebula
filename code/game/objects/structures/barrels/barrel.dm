/obj/structure/reagent_dispensers/barrel
	name                      = "barrel"
	desc                      = "A stout barrel for storing large amounts of liquids or substances."
	icon                      = 'icons/obj/structures/barrels/barrel.dmi'
	icon_state                = ICON_STATE_WORLD
	anchored                  = TRUE
	atom_flags                = ATOM_FLAG_CLIMBABLE
	matter                    = null
	material                  = /decl/material/solid/organic/wood
	color                     = /decl/material/solid/organic/wood::color
	material_alteration       = MAT_FLAG_ALTERATION_COLOR | MAT_FLAG_ALTERATION_NAME | MAT_FLAG_ALTERATION_DESC
	wrenchable                = FALSE
	storage                   = /datum/storage/barrel
	amount_dispensed          = 10
	possible_transfer_amounts = @"[10,25,50,100]"
	volume                    = 7500
	movable_flags             = MOVABLE_FLAG_WHEELED
	throwpass                 = TRUE
	// Should we draw our lid and liquid contents as overlays?
	var/show_liquid_contents  = TRUE
	// Rivets, bands, etc. Currently just cosmetic.
	var/decl/material/metal_material = /decl/material/solid/metal/iron

/obj/structure/reagent_dispensers/barrel/Initialize()
	if(ispath(metal_material))
		metal_material = GET_DECL(metal_material)
	if(!istype(metal_material))
		metal_material = null
	. = ..()
	if(. == INITIALIZE_HINT_NORMAL && storage)
		return INITIALIZE_HINT_LATELOAD //  we want to grab our turf contents.

/obj/structure/reagent_dispensers/barrel/attackby(obj/item/W, mob/user)
	. = ..()
	if(!. && user.a_intent == I_HELP && reagents?.total_volume > FLUID_PUDDLE)
		user.visible_message(SPAN_NOTICE("\The [user] dips \the [W] into \the [reagents.get_primary_reagent_name()]."))
		W.fluid_act(reagents)
		return TRUE

/obj/structure/reagent_dispensers/barrel/LateInitialize(mapload, ...)
	..()
	if(mapload)
		for(var/obj/item/thing in loc)
			if(!thing.simulated || thing.anchored)
				continue
			if(storage.can_be_inserted(thing, null))
				storage.handle_item_insertion(null, thing)

/obj/structure/reagent_dispensers/barrel/on_reagent_change()
	if(!(. = ..()))
		return
	var/primary_mat = reagents?.get_primary_reagent_name()
	if(primary_mat)
		update_material_name("[initial(name)] of [primary_mat]")
	else
		update_material_name()
	update_icon()

/obj/structure/reagent_dispensers/barrel/on_update_icon()

	. = ..()

	// Layer below lid/lid metal.
	if(metal_material)
		add_overlay(overlay_image(icon, "[icon_state]-metal", metal_material.color, RESET_COLOR))

	// Add lid/reagents overlay/lid metal.
	if(show_liquid_contents && ATOM_IS_OPEN_CONTAINER(src))
		if(reagents)
			var/overlay_amount = NONUNIT_CEILING(reagents.total_liquid_volume / reagents.maximum_volume * 100, 10)
			var/image/filling_overlay = overlay_image(icon, "[icon_state]-[overlay_amount]", reagents.get_color(), RESET_COLOR | RESET_ALPHA)
			add_overlay(filling_overlay)
		add_overlay(overlay_image(icon, "[icon_state]-lidopen", material.color, RESET_COLOR))
		if(metal_material)
			add_overlay(overlay_image(icon, "[icon_state]-lidopen-metal", metal_material.color, RESET_COLOR))
	else
		add_overlay(overlay_image(icon, "[icon_state]-lidclosed", material.color, RESET_COLOR))
		if(metal_material)
			add_overlay(overlay_image(icon, "[icon_state]-lidclosed-metal", metal_material.color, RESET_COLOR))

	if(istype(loc, /obj/structure/cask_rack))
		loc.update_icon()

/obj/structure/reagent_dispensers/barrel/ebony
	material = /decl/material/solid/organic/wood/ebony
	color = /decl/material/solid/organic/wood/ebony::color

/obj/structure/reagent_dispensers/barrel/ebony/water/populate_reagents()
	. = ..()
	add_to_reagents(/decl/material/liquid/water, reagents.maximum_volume)

/obj/structure/reagent_dispensers/barrel/ebony/beer/populate_reagents()
	. = ..()
	add_to_reagents(/decl/material/liquid/ethanol/beer, reagents.maximum_volume)

/obj/structure/reagent_dispensers/barrel/ebony/wine/populate_reagents()
	. = ..()
	add_to_reagents(/decl/material/liquid/ethanol/wine, reagents.maximum_volume)

/obj/structure/reagent_dispensers/barrel/ebony/oil/populate_reagents()
	. = ..()
	add_to_reagents(/decl/material/liquid/nutriment/plant_oil, reagents.maximum_volume)
