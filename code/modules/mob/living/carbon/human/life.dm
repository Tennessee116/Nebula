//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:32

//NOTE: Breathing happens once per FOUR TICKS, unless the last breath fails. In which case it happens once per ONE TICK! So oxyloss healing is done once per 4 ticks while oxyloss damage is applied once per tick!
#define HUMAN_MAX_OXYLOSS 1 //Defines how much oxyloss humans can get per tick. A tile with no air at all (such as space) applies this value, otherwise it's a percentage of it.

#define HUMAN_CRIT_TIME_CUSHION (10 MINUTES) //approximate time limit to stabilize someone in crit
#define HUMAN_CRIT_HEALTH_CUSHION (config.health_threshold_crit - config.health_threshold_dead)

//The amount of damage you'll get when in critical condition. We want this to be a HUMAN_CRIT_TIME_CUSHION long deal.
//There are HUMAN_CRIT_HEALTH_CUSHION hp to get through, so (HUMAN_CRIT_HEALTH_CUSHION/HUMAN_CRIT_TIME_CUSHION) per tick.
//Breaths however only happen once every MOB_BREATH_DELAY life ticks. The delay between life ticks is set by the mob process.
#define HUMAN_CRIT_MAX_OXYLOSS ( MOB_BREATH_DELAY * process_schedule_interval("mob") * (HUMAN_CRIT_HEALTH_CUSHION/HUMAN_CRIT_TIME_CUSHION) )

#define HEAT_DAMAGE_LEVEL_1 2 //Amount of damage applied when your body temperature just passes the 360.15k safety point
#define HEAT_DAMAGE_LEVEL_2 4 //Amount of damage applied when your body temperature passes the 400K point
#define HEAT_DAMAGE_LEVEL_3 8 //Amount of damage applied when your body temperature passes the 1000K point

#define COLD_DAMAGE_LEVEL_1 0.5 //Amount of damage applied when your body temperature just passes the 260.15k safety point
#define COLD_DAMAGE_LEVEL_2 1.5 //Amount of damage applied when your body temperature passes the 200K point
#define COLD_DAMAGE_LEVEL_3 3 //Amount of damage applied when your body temperature passes the 120K point

//Note that gas heat damage is only applied once every FOUR ticks.
#define HEAT_GAS_DAMAGE_LEVEL_1 2 //Amount of damage applied when the current breath's temperature just passes the 360.15k safety point
#define HEAT_GAS_DAMAGE_LEVEL_2 4 //Amount of damage applied when the current breath's temperature passes the 400K point
#define HEAT_GAS_DAMAGE_LEVEL_3 8 //Amount of damage applied when the current breath's temperature passes the 1000K point

#define COLD_GAS_DAMAGE_LEVEL_1 0.5 //Amount of damage applied when the current breath's temperature just passes the 260.15k safety point
#define COLD_GAS_DAMAGE_LEVEL_2 1.5 //Amount of damage applied when the current breath's temperature passes the 200K point
#define COLD_GAS_DAMAGE_LEVEL_3 3 //Amount of damage applied when the current breath's temperature passes the 120K point

#define RADIATION_SPEED_COEFFICIENT 0.025

/mob/living/carbon/human
	var/oxygen_alert = 0
	var/toxins_alert = 0
	var/co2_alert = 0
	var/fire_alert = 0
	var/pressure_alert = 0
	var/stamina = 100

/mob/living/carbon/human/Life()
	set invisibility = 0
	set background = BACKGROUND_ENABLED

	if (HAS_TRANSFORMATION_MOVEMENT_HANDLER(src))
		return

	fire_alert = 0 //Reset this here, because both breathe() and handle_environment() have a chance to set it.

	//TODO: seperate this out
	// update the current life tick, can be used to e.g. only do something every 4 ticks
	life_tick++

	// This is not an ideal place for this but it will do for now.
	if(wearing_rig && wearing_rig.offline)
		wearing_rig = null

	..()

	if(life_tick%30==15)
		hud_updateflag = 1022

	voice = GetVoice()

	//No need to update all of these procs if the guy is dead.
	if(stat != DEAD && !InStasis())
		//Updates the number of stored chemicals for powers
		handle_changeling()

		last_pain = null // Clear the last cached pain value so further getHalloss() calls won't use an old value.

		//Organs and blood
		handle_organs()
		stabilize_body_temperature() //Body temperature adjusts itself (self-regulation)

		handle_shock()

		handle_pain()

		handle_stamina()

	if(!handle_some_updates())
		return											//We go ahead and process them 5 times for HUD images and other stuff though.

	//Update our name based on whether our face is obscured/disfigured
	SetName(get_visible_name())

/mob/living/carbon/human/get_stamina()
	return stamina

/mob/living/carbon/human/adjust_stamina(var/amt)
	var/last_stamina = stamina
	if(stat == DEAD)
		stamina = 0
	else
		stamina = clamp(stamina + amt, 0, 100)
		if(stamina <= 0)
			to_chat(src, SPAN_WARNING("You are exhausted!"))
			if(MOVING_QUICKLY(src))
				set_moving_slowly()
	if(last_stamina != stamina && hud_used)
		hud_used.update_stamina()

/mob/living/carbon/human/proc/handle_stamina()
	if((world.time - last_quick_move_time) > 5 SECONDS)
		var/mod = (lying + (nutrition / initial(nutrition))) / 2
		adjust_stamina(max(config.minimum_stamina_recovery, config.maximum_stamina_recovery * mod) * (1 + GET_CHEMICAL_EFFECT(src, CE_ENERGETIC)))

/mob/living/carbon/human/set_stat(var/new_stat)
	var/old_stat = stat
	. = ..()
	if(stat)
		update_skin(1)
	if(client && client.is_afk())
		if(old_stat == UNCONSCIOUS && stat == CONSCIOUS)
			playsound_local(null, 'sound/effects/bells.ogg', 100, is_global=TRUE)

/mob/living/carbon/human/proc/handle_some_updates()
	if(life_tick > 5 && timeofdeath && (timeofdeath < 5 || world.time - timeofdeath > 6000))	//We are long dead, or we're junk mobs spawned like the clowns on the clown shuttle
		return 0
	return 1

/mob/living/carbon/human/breathe()
	var/species_organ = species.breathing_organ

	if(species_organ)
		var/active_breaths = 0
		var/obj/item/organ/internal/lungs/L = get_organ(species_organ, /obj/item/organ/internal/lungs)
		if(L)
			active_breaths = L.active_breathing
		..(active_breaths)

// Calculate how vulnerable the human is to the current pressure.
// Returns 0 (equals 0 %) if sealed in an undamaged suit that's rated for the pressure, 1 if unprotected (equals 100%).
// Suitdamage can modifiy this in 10% steps.
/mob/living/carbon/human/proc/get_pressure_weakness(pressure)

	var/pressure_adjustment_coefficient = 0
	var/list/zones = list(SLOT_HEAD, SLOT_UPPER_BODY, SLOT_LOWER_BODY, SLOT_LEGS, SLOT_FEET, SLOT_ARMS, SLOT_HANDS)
	for(var/zone in zones)
		var/list/covers = get_covering_equipped_items(zone)
		var/zone_exposure = 1
		for(var/obj/item/clothing/C in covers)
			zone_exposure = min(zone_exposure, C.get_pressure_weakness(pressure,zone))
		if(zone_exposure >= 1)
			return 1
		pressure_adjustment_coefficient = max(pressure_adjustment_coefficient, zone_exposure)
	pressure_adjustment_coefficient = clamp(pressure_adjustment_coefficient, 0, 1) // So it isn't less than 0 or larger than 1.

	return pressure_adjustment_coefficient

// Calculate how much of the enviroment pressure-difference affects the human.
/mob/living/carbon/human/calculate_affecting_pressure(var/pressure)
	var/pressure_difference

	// First get the absolute pressure difference.
	if(pressure < ONE_ATMOSPHERE) // We are in an underpressure.
		pressure_difference = ONE_ATMOSPHERE - pressure

	else //We are in an overpressure or standard atmosphere.
		pressure_difference = pressure - ONE_ATMOSPHERE

	if(pressure_difference < 5) // If the difference is small, don't bother calculating the fraction.
		pressure_difference = 0

	else
		// Otherwise calculate how much of that absolute pressure difference affects us, can be 0 to 1 (equals 0% to 100%).
		// This is our relative difference.
		pressure_difference *= get_pressure_weakness(pressure)

	// The difference is always positive to avoid extra calculations.
	// Apply the relative difference on a standard atmosphere to get the final result.
	// The return value will be the adjusted_pressure of the human that is the basis of pressure warnings and damage.
	if(pressure < ONE_ATMOSPHERE)
		return ONE_ATMOSPHERE - pressure_difference
	else
		return ONE_ATMOSPHERE + pressure_difference

/mob/living/carbon/human/handle_impaired_vision()
	..()
	//Vision
	var/obj/item/organ/vision
	if(species.vision_organ)
		vision = GET_INTERNAL_ORGAN(src, species.vision_organ)

	if(!species.vision_organ) // Presumably if a species has no vision organs, they see via some other means.
		set_status(STAT_BLIND, 0)
		blinded =    0
		set_status(STAT_BLURRY, 0)
	else if(!vision || (vision && !vision.is_usable()))   // Vision organs cut out or broken? Permablind.
		set_status(STAT_BLIND, 1)
		blinded =    1
		set_status(STAT_BLURRY, 1)
	else
		//blindness
		if(!(sdisabilities & BLINDED))
			if(equipment_tint_total >= TINT_BLIND)	// Covered eyes, heal faster
				ADJ_STATUS(src, STAT_BLURRY, -1)

/mob/living/carbon/human/handle_disabilities()
	..()
	if(stat != DEAD)
		if ((disabilities & COUGHING) && prob(5) && GET_STATUS(src, STAT_PARA) <= 1)
			drop_held_items()
			cough()

/mob/living/carbon/human/handle_mutations_and_radiation()
	if(getFireLoss())
		if((MUTATION_COLD_RESISTANCE in mutations) || (prob(1)))
			heal_organ_damage(0,1)

	// DNA2 - Gene processing.
	for(var/datum/dna/gene/gene in dna_genes)
		if(!gene.block)
			continue
		if(gene.is_active(src))
			gene.OnMobLife(src)

	radiation = clamp(radiation,0,500)

	if(!radiation)
		if(species.appearance_flags & RADIATION_GLOWS)
			set_light(0)
	else
		if(species.appearance_flags & RADIATION_GLOWS)
			set_light(max(1,min(10,radiation/10)), max(1,min(20,radiation/20)), species.get_flesh_colour(src))
		// END DOGSHIT SNOWFLAKE
		var/damage = 0
		radiation -= 1 * RADIATION_SPEED_COEFFICIENT
		if(prob(25))
			damage = 2

		if (radiation > 50)
			damage = 2
			radiation -= 2 * RADIATION_SPEED_COEFFICIENT
			if(!isSynthetic())
				if(prob(5) && prob(100 * RADIATION_SPEED_COEFFICIENT))
					radiation -= 5 * RADIATION_SPEED_COEFFICIENT
					to_chat(src, "<span class='warning'>You feel weak.</span>")
					SET_STATUS_MAX(src, STAT_WEAK, 3)
					if(!lying)
						emote("collapse")
				if(prob(5) && prob(100 * RADIATION_SPEED_COEFFICIENT))
					lose_hair()

		if (radiation > 75)
			damage = 3
			radiation -= 3 * RADIATION_SPEED_COEFFICIENT
			if(!isSynthetic())
				if(prob(5))
					take_overall_damage(0, 5 * RADIATION_SPEED_COEFFICIENT, used_weapon = "Radiation Burns")
				if(prob(1))
					to_chat(src, "<span class='warning'>You feel strange!</span>")
					adjustCloneLoss(5 * RADIATION_SPEED_COEFFICIENT)
					emote("gasp")
		if(radiation > 150)
			damage = 8
			radiation -= 4 * RADIATION_SPEED_COEFFICIENT

		damage = FLOOR(damage * species.get_radiation_mod(src))
		if(damage)
			adjustToxLoss(damage * RADIATION_SPEED_COEFFICIENT)
			immunity = max(0, immunity - damage * 15 * RADIATION_SPEED_COEFFICIENT)
			updatehealth()
			var/list/limbs = get_external_organs()
			if(!isSynthetic() && LAZYLEN(limbs))
				var/obj/item/organ/external/O = pick(limbs)
				if(istype(O))
					O.add_autopsy_data("Radiation Poisoning", damage)

	/** breathing **/

/mob/living/carbon/human/handle_chemical_smoke(var/datum/gas_mixture/environment)
	for(var/slot in global.standard_headgear_slots)
		var/obj/item/gear = get_equipped_item(slot)
		if(istype(gear) && (gear.item_flags & ITEM_FLAG_BLOCK_GAS_SMOKE_EFFECT))
			return
	..()

/mob/living/carbon/human/get_breath_from_internal(volume_needed=STD_BREATH_VOLUME)
	if(internal)

		var/obj/item/tank/rig_supply
		var/obj/item/rig/rig = get_equipped_item(slot_back_str)
		if(istype(rig) && !rig.offline && (rig.air_supply && internal == rig.air_supply))
			rig_supply = rig.air_supply

		if(!rig_supply)
			if(!contents.Find(internal))
				set_internals(null)
			else
				var/found_mask = FALSE
				for(var/slot in global.airtight_slots)
					var/obj/item/gear = get_equipped_item(slot)
					if(gear && (gear.item_flags & ITEM_FLAG_AIRTIGHT))
						found_mask = TRUE
						break
				if(!found_mask)
					set_internals(null)

		if(internal)
			return internal.remove_air_volume(volume_needed)
	return null

/mob/living/carbon/human/handle_breath(datum/gas_mixture/breath)
	if(status_flags & GODMODE)
		return
	var/species_organ = species.breathing_organ
	if(!species_organ)
		return

	var/obj/item/organ/internal/lungs/L = get_organ(species_organ, /obj/item/organ/internal/lungs)
	if(!L || nervous_system_failure())
		failed_last_breath = 1
	else
		failed_last_breath = L.handle_breath(breath) //if breath is null or vacuum, the lungs will handle it for us
	return !failed_last_breath

/mob/living/carbon/human/handle_environment(datum/gas_mixture/environment)

	..()

	if(!environment || (MUTATION_SPACERES in mutations))
		return

	//Stuff like water absorbtion happens here.
	species.handle_environment_special(src)

	//Moved pressure calculations here for use in skip-processing check.
	var/pressure = environment.return_pressure()
	var/adjusted_pressure = calculate_affecting_pressure(pressure)

	//Check for contaminants before anything else because we don't want to skip it.
	for(var/g in environment.gas)
		var/decl/material/mat = GET_DECL(g)
		if((mat.gas_flags & XGM_GAS_CONTAMINANT) && environment.gas[g] > mat.gas_overlay_limit + 1)
			handle_contaminants()
			break

	if(isspaceturf(src.loc)) //being in a closet will interfere with radiation, may not make sense but we don't model radiation for atoms in general so it will have to do for now.
		//Don't bother if the temperature drop is less than 0.1 anyways. Hopefully BYOND is smart enough to turn this constant expression into a constant
		if(bodytemperature > (0.1 * HUMAN_HEAT_CAPACITY/(HUMAN_EXPOSED_SURFACE_AREA*STEFAN_BOLTZMANN_CONSTANT))**(1/4) + COSMIC_RADIATION_TEMPERATURE)

			//Thermal radiation into space
			var/heat_gain = get_thermal_radiation(bodytemperature, HUMAN_EXPOSED_SURFACE_AREA, 0.5, SPACE_HEAT_TRANSFER_COEFFICIENT)

			var/temperature_gain = heat_gain/HUMAN_HEAT_CAPACITY
			bodytemperature += temperature_gain //temperature_gain will often be negative

	var/relative_density = (environment.total_moles/environment.volume) / (MOLES_CELLSTANDARD/CELL_VOLUME)
	if(relative_density > 0.02) //don't bother if we are in vacuum or near-vacuum
		var/loc_temp = environment.temperature

		if(adjusted_pressure < species.warning_high_pressure && adjusted_pressure > species.warning_low_pressure && abs(loc_temp - bodytemperature) < 20 && bodytemperature < species.heat_level_1 && bodytemperature > species.cold_level_1 && species.body_temperature)
			pressure_alert = 0
			return // Temperatures are within normal ranges, fuck all this processing. ~Ccomp

		//Body temperature adjusts depending on surrounding atmosphere based on your thermal protection (convection)
		var/temp_adj = 0
		if(loc_temp < bodytemperature)			//Place is colder than we are
			var/thermal_protection = get_cold_protection(loc_temp) //This returns a 0 - 1 value, which corresponds to the percentage of protection based on what you're wearing and what you're exposed to.
			if(thermal_protection < 1)
				temp_adj = (1-thermal_protection) * ((loc_temp - bodytemperature) / BODYTEMP_COLD_DIVISOR)	//this will be negative
		else if (loc_temp > bodytemperature)			//Place is hotter than we are
			var/thermal_protection = get_heat_protection(loc_temp) //This returns a 0 - 1 value, which corresponds to the percentage of protection based on what you're wearing and what you're exposed to.
			if(thermal_protection < 1)
				temp_adj = (1-thermal_protection) * ((loc_temp - bodytemperature) / BODYTEMP_HEAT_DIVISOR)

		//Use heat transfer as proportional to the gas density. However, we only care about the relative density vs standard 101 kPa/20 C air. Therefore we can use mole ratios
		bodytemperature += clamp(BODYTEMP_COOLING_MAX, temp_adj*relative_density, BODYTEMP_HEATING_MAX)

	// +/- 50 degrees from 310.15K is the 'safe' zone, where no damage is dealt.
	if(bodytemperature >= getSpeciesOrSynthTemp(HEAT_LEVEL_1))
		//Body temperature is too hot.
		fire_alert = max(fire_alert, 1)
		if(status_flags & GODMODE)	return 1	//godmode
		var/burn_dam = 0
		if(bodytemperature < getSpeciesOrSynthTemp(HEAT_LEVEL_2))
			burn_dam = HEAT_DAMAGE_LEVEL_1
		else if(bodytemperature < getSpeciesOrSynthTemp(HEAT_LEVEL_3))
			burn_dam = HEAT_DAMAGE_LEVEL_2
		else
			burn_dam = HEAT_DAMAGE_LEVEL_3
		take_overall_damage(burn=burn_dam, used_weapon = "High Body Temperature")
		fire_alert = max(fire_alert, 2)

	else if(bodytemperature <= getSpeciesOrSynthTemp(COLD_LEVEL_1))
		fire_alert = max(fire_alert, 1)
		if(status_flags & GODMODE)	return 1	//godmode

		var/burn_dam = 0

		if(bodytemperature > getSpeciesOrSynthTemp(COLD_LEVEL_2))
			burn_dam = COLD_DAMAGE_LEVEL_1
		else if(bodytemperature > getSpeciesOrSynthTemp(COLD_LEVEL_3))
			burn_dam = COLD_DAMAGE_LEVEL_2
		else
			burn_dam = COLD_DAMAGE_LEVEL_3
		SetStasis(getCryogenicFactor(bodytemperature), STASIS_COLD)
		if(!has_chemical_effect(CE_CRYO, 1))
			take_overall_damage(burn=burn_dam, used_weapon = "Low Body Temperature")
			fire_alert = max(fire_alert, 1)

	// Account for massive pressure differences.  Done by Polymorph
	// Made it possible to actually have something that can protect against high pressure... Done by Errorage. Polymorph now has an axe sticking from his head for his previous hardcoded nonsense!
	if(status_flags & GODMODE)	return 1	//godmode

	if(adjusted_pressure >= species.hazard_high_pressure)
		var/pressure_damage = min( ( (adjusted_pressure / species.hazard_high_pressure) -1 )*PRESSURE_DAMAGE_COEFFICIENT , MAX_HIGH_PRESSURE_DAMAGE)
		take_overall_damage(brute=pressure_damage, used_weapon = "High Pressure")
		pressure_alert = 2
	else if(adjusted_pressure >= species.warning_high_pressure)
		pressure_alert = 1
	else if(adjusted_pressure >= species.warning_low_pressure)
		pressure_alert = 0
	else if(adjusted_pressure >= species.hazard_low_pressure)
		pressure_alert = -1
	else
		var/list/obj/item/organ/external/parts = get_damageable_organs()
		for(var/obj/item/organ/external/O in parts)
			if(QDELETED(O) || !(O.owner == src))
				continue
			if(O.damage + (LOW_PRESSURE_DAMAGE) < O.min_broken_damage) //vacuum does not break bones
				O.take_external_damage(brute = LOW_PRESSURE_DAMAGE, used_weapon = "Low Pressure")
		if(getOxyLossPercent() < 55) // 11 OxyLoss per 4 ticks when wearing internals;    unconsciousness in 16 ticks, roughly half a minute
			adjustOxyLoss(4)  // 16 OxyLoss per 4 ticks when no internals present; unconsciousness in 13 ticks, roughly twenty seconds
		pressure_alert = -2

	return

/mob/living/carbon/human/proc/stabilize_body_temperature()
	// We produce heat naturally.
	if (species.passive_temp_gain)
		bodytemperature += species.passive_temp_gain

	// Robolimbs cause overheating too.
	if(robolimb_count)
		bodytemperature += round(robolimb_count/2)

	if (species.body_temperature == null || isSynthetic())
		return //this species doesn't have metabolic thermoregulation

	var/body_temperature_difference = species.body_temperature - bodytemperature

	if (abs(body_temperature_difference) < 0.5)
		return //fuck this precision

	if (on_fire)
		return //too busy for pesky metabolic regulation

	if(bodytemperature < species.cold_level_1) //260.15 is 310.15 - 50, the temperature where you start to feel effects.
		var/nut_remove = 10 * DEFAULT_HUNGER_FACTOR
		if(nutrition >= nut_remove) //If we are very, very cold we'll use up quite a bit of nutriment to heat us up.
			adjust_nutrition(-nut_remove)
			bodytemperature += max((body_temperature_difference / BODYTEMP_AUTORECOVERY_DIVISOR), BODYTEMP_AUTORECOVERY_MINIMUM)
	else if(species.cold_level_1 <= bodytemperature && bodytemperature <= species.heat_level_1)
		bodytemperature += body_temperature_difference / BODYTEMP_AUTORECOVERY_DIVISOR
	else if(bodytemperature > species.heat_level_1) //360.15 is 310.15 + 50, the temperature where you start to feel effects.
		var/hyd_remove = 10 * DEFAULT_THIRST_FACTOR
		if(hydration >= hyd_remove)
			adjust_hydration(-hyd_remove)
			bodytemperature += min((body_temperature_difference / BODYTEMP_AUTORECOVERY_DIVISOR), -BODYTEMP_AUTORECOVERY_MINIMUM)

	//This proc returns a number made up of the flags for body parts which you are protected on. (such as HEAD, SLOT_UPPER_BODY, SLOT_LOWER_BODY, etc. See setup.dm for the full list)
/mob/living/carbon/human/proc/get_heat_protection_flags(temperature) //Temperature is the temperature you're being exposed to.
	. = 0
	//Handle normal clothing
	for(var/slot in global.standard_clothing_slots)
		var/obj/item/clothing/C = get_equipped_item(slot)
		if(istype(C))
			if(C.max_heat_protection_temperature && C.max_heat_protection_temperature >= temperature)
				. |= C.heat_protection
			if(C.accessories.len)
				for(var/obj/item/clothing/accessory/A in C.accessories)
					if(A.max_heat_protection_temperature && A.max_heat_protection_temperature >= temperature)
						. |= A.heat_protection

//See proc/get_heat_protection_flags(temperature) for the description of this proc.
/mob/living/carbon/human/proc/get_cold_protection_flags(temperature)
	. = 0
	//Handle normal clothing
	for(var/slot in global.standard_clothing_slots)
		var/obj/item/clothing/C = get_equipped_item(slot)
		if(istype(C))
			if(C.min_cold_protection_temperature && C.min_cold_protection_temperature <= temperature)
				. |= C.cold_protection
			if(C.accessories.len)
				for(var/obj/item/clothing/accessory/A in C.accessories)
					if(A.min_cold_protection_temperature && A.min_cold_protection_temperature <= temperature)
						. |= A.cold_protection


/mob/living/carbon/human/get_heat_protection(temperature) //Temperature is the temperature you're being exposed to.
	var/thermal_protection_flags = get_heat_protection_flags(temperature)
	return get_thermal_protection(thermal_protection_flags)

/mob/living/carbon/human/get_cold_protection(temperature)
	if(MUTATION_COLD_RESISTANCE in mutations)
		return 1 //Fully protected from the cold.

	temperature = max(temperature, 2.7) //There is an occasional bug where the temperature is miscalculated in ares with a small amount of gas on them, so this is necessary to ensure that that bug does not affect this calculation. Space's temperature is 2.7K and most suits that are intended to protect against any cold, protect down to 2.0K.
	var/thermal_protection_flags = get_cold_protection_flags(temperature)
	return get_thermal_protection(thermal_protection_flags)

/mob/living/carbon/human/proc/get_thermal_protection(var/flags)
	.=0
	if(flags)
		if(flags & SLOT_HEAD)
			. += THERMAL_PROTECTION_HEAD
		if(flags & SLOT_UPPER_BODY)
			. += THERMAL_PROTECTION_UPPER_TORSO
		if(flags & SLOT_LOWER_BODY)
			. += THERMAL_PROTECTION_LOWER_TORSO
		if(flags & SLOT_LEG_LEFT)
			. += THERMAL_PROTECTION_LEG_LEFT
		if(flags & SLOT_LEG_RIGHT)
			. += THERMAL_PROTECTION_LEG_RIGHT
		if(flags & SLOT_FOOT_LEFT)
			. += THERMAL_PROTECTION_FOOT_LEFT
		if(flags & SLOT_FOOT_RIGHT)
			. += THERMAL_PROTECTION_FOOT_RIGHT
		if(flags & SLOT_ARM_LEFT)
			. += THERMAL_PROTECTION_ARM_LEFT
		if(flags & SLOT_ARM_RIGHT)
			. += THERMAL_PROTECTION_ARM_RIGHT
		if(flags & SLOT_HAND_LEFT)
			. += THERMAL_PROTECTION_HAND_LEFT
		if(flags & SLOT_HAND_RIGHT)
			. += THERMAL_PROTECTION_HAND_RIGHT
	return min(1,.)

/mob/living/carbon/human/apply_chemical_effects()
	. = ..()
	if(has_chemical_effect(CE_GLOWINGEYES, 1))
		update_eyes()
		return TRUE

/mob/living/carbon/human/handle_regular_status_updates()
	if(!handle_some_updates())
		return 0

	if(status_flags & GODMODE)	return 0

	//SSD check, if a logged player is awake put them back to sleep!
	if(stat == DEAD)	//DEAD. BROWN BREAD. SWIMMING WITH THE SPESS CARP
		blinded = 1
		set_status(STAT_SILENCE, 0)
	else				//ALIVE. LIGHTS ARE ON
		updatehealth()	//TODO

		if(hallucination_power)
			handle_hallucinations()

		if(get_shock() >= species.total_health)
			if(!stat)
				to_chat(src, "<span class='warning'>[species.halloss_message_self]</span>")
				src.visible_message("<B>[src]</B> [species.halloss_message]")
			SET_STATUS_MAX(src, STAT_PARA, 10)

		if(HAS_STATUS(src, STAT_PARA) ||HAS_STATUS(src, STAT_ASLEEP))
			blinded = 1
			set_stat(UNCONSCIOUS)
			animate_tail_reset()
			adjustHalLoss(-3)

			if(prob(2) && is_asystole() && isSynthetic())
				visible_message("<b>[src]</b> [pick("emits low pitched whirr","beeps urgently")].")
		//CONSCIOUS
		else
			set_stat(CONSCIOUS)

		// Check everything else.

		//Periodically double-check embedded_flag
		if(embedded_flag && !(life_tick % 10))
			if(!embedded_needs_process())
				embedded_flag = 0

		//Resting
		if(resting)
			if(HAS_STATUS(src, STAT_DIZZY))
				ADJ_STATUS(src, STAT_DIZZY, -15)
			if(HAS_STATUS(src, STAT_JITTER))
				ADJ_STATUS(src, STAT_JITTER, -15)
			adjustHalLoss(-3)
		else
			if(HAS_STATUS(src, STAT_DIZZY))
				ADJ_STATUS(src, STAT_DIZZY, -3)
			if(HAS_STATUS(src, STAT_JITTER))
				ADJ_STATUS(src, STAT_JITTER, -3)
			adjustHalLoss(-1)

		if(HAS_STATUS(src, STAT_DROWSY))
			SET_STATUS_MAX(src, STAT_BLURRY, 2)
			var/sleepy = GET_STATUS(src, STAT_DROWSY)
			if(sleepy > 10)
				var/zzzchance = min(5, 5*sleepy/30)
				if((prob(zzzchance) || sleepy >= 60))
					if(stat == CONSCIOUS)
						to_chat(src, "<span class='notice'>You are about to fall asleep...</span>")
					SET_STATUS_MAX(src, STAT_ASLEEP, 5)

		// If you're dirty, your gloves will become dirty, too.
		var/obj/item/gloves = get_equipped_item(slot_gloves_str)
		if(gloves && germ_level > gloves.germ_level && prob(10))
			gloves.germ_level += 1

		if(vsc.contaminant_control.CONTAMINATION_LOSS)
			var/total_contamination= 0
			for(var/obj/item/I in src)
				if(I.contaminated)
					total_contamination += vsc.contaminant_control.CONTAMINATION_LOSS
			adjustToxLoss(total_contamination)

		// nutrition decrease
		if(nutrition > 0)
			adjust_nutrition(-species.hunger_factor)
		if(hydration > 0)
			adjust_hydration(-species.thirst_factor)

		if(stasis_value > 1 && GET_STATUS(src, STAT_DROWSY) < stasis_value * 4)
			ADJ_STATUS(src, STAT_DROWSY, min(stasis_value, 3))
			if(!stat && prob(1))
				to_chat(src, "<span class='notice'>You feel slow and sluggish...</span>")

	return 1

/mob/living/carbon/human/handle_regular_hud_updates()
	if(hud_updateflag) // update our mob's hud overlays, AKA what others see flaoting above our head
		handle_hud_list()

	// now handle what we see on our screen

	if(!..())
		return

	if(stat != DEAD)
		if(stat == UNCONSCIOUS && health < maxHealth/2)
			//Critical damage passage overlay
			var/severity = 0
			switch(health - maxHealth/2)
				if(-20 to -10)			severity = 1
				if(-30 to -20)			severity = 2
				if(-40 to -30)			severity = 3
				if(-50 to -40)			severity = 4
				if(-60 to -50)			severity = 5
				if(-70 to -60)			severity = 6
				if(-80 to -70)			severity = 7
				if(-90 to -80)			severity = 8
				if(-95 to -90)			severity = 9
				if(-INFINITY to -95)	severity = 10
			overlay_fullscreen("crit", /obj/screen/fullscreen/crit, severity)
		else
			clear_fullscreen("crit")
			//Oxygen damage overlay
			if(getOxyLoss())
				var/severity = 0
				switch(getOxyLossPercent())
					if(10 to 20)		severity = 1
					if(20 to 25)		severity = 2
					if(25 to 30)		severity = 3
					if(30 to 35)		severity = 4
					if(35 to 40)		severity = 5
					if(40 to 45)		severity = 6
					if(45 to INFINITY)	severity = 7
				overlay_fullscreen("oxy", /obj/screen/fullscreen/oxy, severity)
			else
				clear_fullscreen("oxy")

		//Fire and Brute damage overlay (BSSR)
		var/hurtdamage = src.getBruteLoss() + src.getFireLoss() + damageoverlaytemp
		damageoverlaytemp = 0 // We do this so we can detect if someone hits us or not.
		if(hurtdamage)
			var/severity = 0
			switch(hurtdamage)
				if(10 to 25)		severity = 1
				if(25 to 40)		severity = 2
				if(40 to 55)		severity = 3
				if(55 to 70)		severity = 4
				if(70 to 85)		severity = 5
				if(85 to INFINITY)	severity = 6
			overlay_fullscreen("brute", /obj/screen/fullscreen/brute, severity)
		else
			clear_fullscreen("brute")

		if(healths)

			var/mutable_appearance/healths_ma = new(healths)
			healths_ma.icon_state = "blank"
			healths_ma.overlays = null

			if(has_chemical_effect(CE_PAINKILLER, 100))
				healths_ma.icon_state = "health_numb"
			else
				// Generate a by-limb health display.
				var/no_damage = 1
				var/trauma_val = 0 // Used in calculating softcrit/hardcrit indicators.
				if(can_feel_pain())
					trauma_val = max(shock_stage,get_shock())/(species.total_health-100)
				// Collect and apply the images all at once to avoid appearance churn.
				var/list/health_images = list()
				for(var/obj/item/organ/external/E in get_external_organs())
					if(no_damage && (E.brute_dam || E.burn_dam))
						no_damage = 0
					health_images += E.get_damage_hud_image()

				// Apply a fire overlay if we're burning.
				if(on_fire)
					health_images += image('icons/mob/screen1_health.dmi',"burning")

				// Show a general pain/crit indicator if needed.
				if(is_asystole())
					health_images += image('icons/mob/screen1_health.dmi',"hardcrit")
				else if(trauma_val)
					if(can_feel_pain())
						if(trauma_val > 0.7)
							health_images += image('icons/mob/screen1_health.dmi',"softcrit")
						if(trauma_val >= 1)
							health_images += image('icons/mob/screen1_health.dmi',"hardcrit")
				else if(no_damage)
					health_images += image('icons/mob/screen1_health.dmi',"fullhealth")
				healths_ma.overlays += health_images
			healths.appearance = healths_ma

		if(nutrition_icon)
			switch(nutrition)
				if(450 to INFINITY)				nutrition_icon.icon_state = "nutrition0"
				if(350 to 450)					nutrition_icon.icon_state = "nutrition1"
				if(250 to 350)					nutrition_icon.icon_state = "nutrition2"
				if(150 to 250)					nutrition_icon.icon_state = "nutrition3"
				else							nutrition_icon.icon_state = "nutrition4"

		if(hydration_icon)
			switch(hydration)
				if(450 to INFINITY)				hydration_icon.icon_state = "hydration0"
				if(350 to 450)					hydration_icon.icon_state = "hydration1"
				if(250 to 350)					hydration_icon.icon_state = "hydration2"
				if(150 to 250)					hydration_icon.icon_state = "hydration3"
				else							hydration_icon.icon_state = "hydration4"

		if(isSynthetic())
			var/obj/item/organ/internal/cell/C = get_organ(BP_CELL, /obj/item/organ/internal/cell)
			if(C)
				var/chargeNum = clamp(CEILING(C.percent()/25), 0, 4)	//0-100 maps to 0-4, but give it a paranoid clamp just in case.
				cells.icon_state = "charge[chargeNum]"
			else
				cells.icon_state = "charge-empty"

		if(pressure)
			pressure.icon_state = "pressure[pressure_alert]"
		if(toxin)
			toxin.icon_state = "tox[toxins_alert ? "1" : "0"]"
		if(oxygen)
			oxygen.icon_state = "oxy[oxygen_alert ? "1" : "0"]"
		if(fire)
			fire.icon_state = "fire[fire_alert ? fire_alert : 0]"

		if(bodytemp)
			if (!species)
				switch(bodytemperature) //310.055 optimal body temp
					if(370 to INFINITY)		bodytemp.icon_state = "temp4"
					if(350 to 370)			bodytemp.icon_state = "temp3"
					if(335 to 350)			bodytemp.icon_state = "temp2"
					if(320 to 335)			bodytemp.icon_state = "temp1"
					if(300 to 320)			bodytemp.icon_state = "temp0"
					if(295 to 300)			bodytemp.icon_state = "temp-1"
					if(280 to 295)			bodytemp.icon_state = "temp-2"
					if(260 to 280)			bodytemp.icon_state = "temp-3"
					else					bodytemp.icon_state = "temp-4"
			else
				//TODO: precalculate all of this stuff when the species datum is created
				var/base_temperature = species.body_temperature
				if(base_temperature == null) //some species don't have a set metabolic temperature
					base_temperature = (getSpeciesOrSynthTemp(HEAT_LEVEL_1) + getSpeciesOrSynthTemp(COLD_LEVEL_1))/2

				var/temp_step
				if (bodytemperature >= base_temperature)
					temp_step = (getSpeciesOrSynthTemp(HEAT_LEVEL_1) - base_temperature)/4

					if (bodytemperature >= getSpeciesOrSynthTemp(HEAT_LEVEL_1))
						bodytemp.icon_state = "temp4"
					else if (bodytemperature >= base_temperature + temp_step*3)
						bodytemp.icon_state = "temp3"
					else if (bodytemperature >= base_temperature + temp_step*2)
						bodytemp.icon_state = "temp2"
					else if (bodytemperature >= base_temperature + temp_step*1)
						bodytemp.icon_state = "temp1"
					else
						bodytemp.icon_state = "temp0"

				else if (bodytemperature < base_temperature)
					temp_step = (base_temperature - getSpeciesOrSynthTemp(COLD_LEVEL_1))/4

					if (bodytemperature <= getSpeciesOrSynthTemp(COLD_LEVEL_1))
						bodytemp.icon_state = "temp-4"
					else if (bodytemperature <= base_temperature - temp_step*3)
						bodytemp.icon_state = "temp-3"
					else if (bodytemperature <= base_temperature - temp_step*2)
						bodytemp.icon_state = "temp-2"
					else if (bodytemperature <= base_temperature - temp_step*1)
						bodytemp.icon_state = "temp-1"
					else
						bodytemp.icon_state = "temp0"
	return 1

/mob/living/carbon/human/handle_random_events()
	// Puke if toxloss is too high
	var/vomit_score = 0
	for(var/tag in list(BP_LIVER,BP_KIDNEYS))
		var/obj/item/organ/internal/I = GET_INTERNAL_ORGAN(src, tag)
		if(I)
			vomit_score += I.damage
		else if (should_have_organ(tag))
			vomit_score += 45
	if(has_chemical_effect(CE_TOXIN, 1) || radiation)
		vomit_score += 0.5 * getToxLoss()
	if(has_chemical_effect(CE_ALCOHOL_TOXIC, 1))
		vomit_score += 10 * GET_CHEMICAL_EFFECT(src, CE_ALCOHOL_TOXIC)
	if(has_chemical_effect(CE_ALCOHOL, 1))
		vomit_score += 10
	if(stat != DEAD && vomit_score > 25 && prob(10))
		vomit(vomit_score, vomit_score/25)

	//0.1% chance of playing a scary sound to someone who's in complete darkness
	if(isturf(loc) && rand(1,1000) == 1)
		var/turf/T = loc
		if(T.get_lumcount() <= LIGHTING_SOFT_THRESHOLD)
			playsound_local(src,pick(global.scarySounds),50, 1, -1)

	var/area/A = get_area(src)
	if(client && world.time >= client.played + 60 SECONDS)
		A.play_ambience(src)
	if(stat == UNCONSCIOUS && world.time - l_move_time < 5 && prob(10))
		to_chat(src,"<span class='notice'>You feel like you're [pick("moving","flying","floating","falling","hovering")].</span>")

/mob/living/carbon/human/proc/handle_changeling()
	if(mind && mind.changeling)
		mind.changeling.regenerate()

#define BASE_SHOCK_RECOVERY 1
/mob/living/carbon/human/proc/handle_shock()
	if(!can_feel_pain() || (status_flags & GODMODE))
		shock_stage = 0
		return

	var/stress_modifier = get_stress_modifier()
	if(stress_modifier)
		stress_modifier *= config.stress_shock_recovery_constant

	if(is_asystole())
		shock_stage = max(shock_stage + (BASE_SHOCK_RECOVERY + stress_modifier), 61)

	var/traumatic_shock = get_shock()
	if(traumatic_shock >= max(30, 0.8*shock_stage))
		shock_stage += (1 + stress_modifier)
	else if (!is_asystole())
		shock_stage = min(shock_stage, 160)
		var/recovery = 1
		if(traumatic_shock < 0.5 * shock_stage) //lower shock faster if pain is gone completely
			recovery++
		if(traumatic_shock < 0.25 * shock_stage)
			recovery++
		shock_stage = max(shock_stage - (recovery * (1-stress_modifier)), 0)
		return

	if(stat != CONSCIOUS)
		return

	// If we haven't adjusted by at least one full unit, don't run the message logic below.
	var/next_rounded_shock_stage = round(shock_stage)
	if(next_rounded_shock_stage == rounded_shock_stage)
		return

	rounded_shock_stage = next_rounded_shock_stage
	if(rounded_shock_stage <= 0)
		return

	if(rounded_shock_stage == 10)
		// Please be very careful when calling custom_pain() from within code that relies on pain/trauma values. There's the
		// possibility of a feedback loop from custom_pain() being called with a positive power, incrementing pain on a limb,
		// which triggers this proc, which calls custom_pain(), etc. Make sure you call it with nohalloss = TRUE in these cases!
		custom_pain("[pick("It hurts so much", "You really need some painkillers", "Dear god, the pain")]!", 10, nohalloss = TRUE)

	if(rounded_shock_stage >= 30)
		if(rounded_shock_stage == 30)
			var/decl/pronouns/G = get_pronouns()
			visible_message("<b>\The [src]</b> is having trouble keeping [G.his] eyes open.")
		if(prob(30))
			SET_STATUS_MAX(src, STAT_BLURRY, 2)
			SET_STATUS_MAX(src, STAT_STUTTER, 5)

	if (rounded_shock_stage >= 60)
		if(rounded_shock_stage == 60) visible_message("<b>[src]</b>'s body becomes limp.")
		if (prob(2))
			custom_pain("[pick("The pain is excruciating", "Please, just end the pain", "Your whole body is going numb")]!", rounded_shock_stage, nohalloss = TRUE)
			SET_STATUS_MAX(src, STAT_WEAK, 3)

	if(rounded_shock_stage >= 80)
		if (prob(5))
			custom_pain("[pick("The pain is excruciating", "Please, just end the pain", "Your whole body is going numb")]!", rounded_shock_stage, nohalloss = TRUE)
			SET_STATUS_MAX(src, STAT_WEAK, 5)

	if(rounded_shock_stage >= 120)
		if(!HAS_STATUS(src, STAT_PARA) && prob(2))
			custom_pain("[pick("You black out", "You feel like you could die any moment now", "You're about to lose consciousness")]!", rounded_shock_stage, nohalloss = TRUE)
			SET_STATUS_MAX(src, STAT_PARA, 5)

	if(rounded_shock_stage == 150)
		visible_message("<b>[src]</b> can no longer stand, collapsing!")

	if(rounded_shock_stage >= 150)
		SET_STATUS_MAX(src, STAT_WEAK, 5)

#undef BASE_SHOCK_RECOVERY

/*
	Called by life(), instead of having the individual hud items update icons each tick and check for status changes
	we only set those statuses and icons upon changes.  Then those HUD items will simply add those pre-made images.
	This proc below is only called when those HUD elements need to change as determined by the mobs hud_updateflag.
*/
/mob/living/carbon/human/proc/handle_hud_list()
	if (BITTEST(hud_updateflag, HEALTH_HUD) && hud_list[HEALTH_HUD])
		var/image/holder = hud_list[HEALTH_HUD]
		if(stat == DEAD)
			holder.icon_state = "0" 	// X_X
		else if(is_asystole())
			holder.icon_state = "flatline"
		else
			holder.icon_state = "[pulse()]"
		hud_list[HEALTH_HUD] = holder

	if (BITTEST(hud_updateflag, LIFE_HUD) && hud_list[LIFE_HUD])
		var/image/holder = hud_list[LIFE_HUD]
		if(stat == DEAD)
			holder.icon_state = "huddead"
		else
			holder.icon_state = "hudhealthy"
		hud_list[LIFE_HUD] = holder

	if (BITTEST(hud_updateflag, STATUS_HUD) && hud_list[STATUS_HUD] && hud_list[STATUS_HUD_OOC])
		var/image/holder = hud_list[STATUS_HUD]
		if(stat == DEAD)
			holder.icon_state = "huddead"
		else
			holder.icon_state = "hudhealthy"

		var/image/holder2 = hud_list[STATUS_HUD_OOC]
		if(stat == DEAD)
			holder2.icon_state = "huddead"
		else
			holder2.icon_state = "hudhealthy"

		hud_list[STATUS_HUD] = holder
		hud_list[STATUS_HUD_OOC] = holder2

	if (BITTEST(hud_updateflag, ID_HUD) && hud_list[ID_HUD])
		var/image/holder = hud_list[ID_HUD]
		holder.icon_state = "hudunknown"

		var/obj/item/id = get_equipped_item(slot_wear_id_str)
		if(id)
			var/obj/item/card/id/I = id.GetIdCard()
			if(I)
				var/datum/job/J = SSjobs.get_by_title(I.GetJobName())
				if(J)
					holder.icon_state = J.hud_icon

		hud_list[ID_HUD] = holder

	if (BITTEST(hud_updateflag, WANTED_HUD) && hud_list[WANTED_HUD])
		var/image/holder = hud_list[WANTED_HUD]
		holder.icon_state = "hudblank"
		var/perpname = name
		var/obj/item/id = get_equipped_item(slot_wear_id_str)
		if(id)
			var/obj/item/card/id/I = id.GetIdCard()
			if(I)
				perpname = I.registered_name

		var/datum/computer_file/report/crew_record/E = get_crewmember_record(perpname)
		if(E)
			switch(E.get_criminalStatus())
				if("Arrest")
					holder.icon_state = "hudwanted"
				if("Incarcerated")
					holder.icon_state = "hudprisoner"
				if("Parolled")
					holder.icon_state = "hudparolled"
				if("Released")
					holder.icon_state = "hudreleased"
		hud_list[WANTED_HUD] = holder

	if (  BITTEST(hud_updateflag, IMPLOYAL_HUD) \
	   || BITTEST(hud_updateflag,  IMPCHEM_HUD) \
	   || BITTEST(hud_updateflag, IMPTRACK_HUD))

		var/image/holder1 = hud_list[IMPTRACK_HUD]
		var/image/holder2 = hud_list[IMPLOYAL_HUD]
		var/image/holder3 = hud_list[IMPCHEM_HUD]

		holder1.icon_state = "hudblank"
		holder2.icon_state = "hudblank"
		holder3.icon_state = "hudblank"

		for(var/obj/item/implant/I in src)
			if(I.implanted)
				if(istype(I,/obj/item/implant/tracking))
					holder1.icon_state = "hud_imp_tracking"
				if(istype(I,/obj/item/implant/loyalty))
					holder2.icon_state = "hud_imp_loyal"
				if(istype(I,/obj/item/implant/chem))
					holder3.icon_state = "hud_imp_chem"

		hud_list[IMPTRACK_HUD] = holder1
		hud_list[IMPLOYAL_HUD] = holder2
		hud_list[IMPCHEM_HUD]  = holder3

	if (BITTEST(hud_updateflag, SPECIALROLE_HUD))
		var/image/holder = hud_list[SPECIALROLE_HUD]
		holder.icon_state = "hudblank"
		var/special_role = mind?.get_special_role_name()
		if(special_role)
			if(global.hud_icon_reference[special_role])
				holder.icon_state = global.hud_icon_reference[special_role]
			else
				holder.icon_state = "hudsyndicate"
			hud_list[SPECIALROLE_HUD] = holder
	hud_updateflag = 0

/mob/living/carbon/human/handle_fire()
	if(..())
		return

	var/burn_temperature = fire_burn_temperature()
	var/thermal_protection = get_heat_protection(burn_temperature)

	if (thermal_protection < 1 && bodytemperature < burn_temperature)
		bodytemperature += round(BODYTEMP_HEATING_MAX*(1-thermal_protection), 1)

	var/species_heat_mod = 1

	var/protected_limbs = get_heat_protection_flags(burn_temperature)


	if(species)
		if(burn_temperature < species.heat_level_2)
			species_heat_mod = 0.5
		else if(burn_temperature < species.heat_level_3)
			species_heat_mod = 0.75

	burn_temperature -= species.heat_level_1

	if(burn_temperature < 1)
		return

	for(var/obj/item/organ/external/E in get_external_organs())
		if(!(E.body_part & protected_limbs) && prob(20))
			E.take_external_damage(burn = round(species_heat_mod * log(10, (burn_temperature + 10)), 0.1), used_weapon = "fire")

/mob/living/carbon/human/rejuvenate()
	reset_blood()
	full_prosthetic = null
	shock_stage = 0
	..()
	adjust_stamina(100)
	UpdateAppearance()

/mob/living/carbon/human/reset_view(atom/A)
	..()
	if(machine_visual && machine_visual != A)
		machine_visual.remove_visual(src)
	if(eyeobj)
		eyeobj.remove_visual(src)

/mob/living/carbon/human/handle_vision()
	if(client)
		var/datum/global_hud/global_hud = get_global_hud()
		client.screen.Remove(global_hud.nvg, global_hud.thermal, global_hud.meson, global_hud.science)
	if(machine)
		var/viewflags = machine.check_eye(src)
		if(viewflags < 0)
			reset_view(null, 0)
		else if(viewflags)
			set_sight(sight|viewflags)
	if(eyeobj && eyeobj.owner != src)
		reset_view(null)
	if((mRemote in mutations) && remoteview_target && remoteview_target.stat != CONSCIOUS)
		remoteview_target = null
		reset_view(null, 0)

	update_equipment_vision()
	species.handle_vision(src)

/mob/living/carbon/human/update_living_sight()
	..()
	if(GET_CHEMICAL_EFFECT(src, CE_THIRDEYE) || (MUTATION_XRAY in mutations))
		set_sight(sight|SEE_TURFS|SEE_MOBS|SEE_OBJS)
