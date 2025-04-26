CREATE OR REPLACE FUNCTION get_max_health(f_char_id INT)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    max_health NUMERIC;
BEGIN
    -- Get base health and health modifier
	SELECT 
		-- TODO I want to introduce constitution here
        cl.base_health + (cl.base_health * (cl.health_modifier/100)) + cl.base_health * 
        COALESCE((
			SELECT SUM(im.effect_factor*i.quantity) -- character_inventory quantity is important
			FROM character_inventory i 
			JOIN item_table it ON i.item_id = it.id
			JOIN item_modifiers im on im.item_id = it.id
	        WHERE i.owner_id = f_char_id AND im.affected_att = 'HP'
		), 0) /100 -- values ranging from 0-100%
    INTO max_health
    FROM characters c
    JOIN classes cl ON c.class_id = cl.id
    WHERE c.id = f_char_id;
    RETURN max_health;
END;
$$;
CREATE OR REPLACE FUNCTION items_weight(f_char_id INT)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
BEGIN
    -- Get weight of items
	Return(
			coalesce(
			(SELECT SUM(it.weight*i.quantity) -- character_inventory quantity is important
				FROM character_inventory i 
				JOIN item_table it ON i.item_id = it.id
	        	WHERE i.owner_id = f_char_id)
			,0)
	);
END;
$$;

CREATE OR REPLACE PROCEDURE update_character_attributes(character_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    -- Base attributes (from class table)
    class_base_str NUMERIC;
    class_base_dex NUMERIC;
    class_base_int NUMERIC;
    class_base_con NUMERIC;
    class_base_enc NUMERIC;
    class_base_def NUMERIC;
    class_base_ap NUMERIC;
    
    -- Class modifiers
    class_str_mod NUMERIC;
    class_dex_mod NUMERIC;
    class_int_mod NUMERIC;
    class_con_mod NUMERIC;
    class_enc_mod NUMERIC;
    class_def_mod NUMERIC;
    class_ap_mod NUMERIC;
    
    -- Item bonuses
    item_str_bonus NUMERIC := 0;
    item_dex_bonus NUMERIC := 0;
    item_int_bonus NUMERIC := 0;
    item_con_bonus NUMERIC := 0;
    item_enc_bonus NUMERIC := 0;
    item_def_bonus NUMERIC := 0;
    item_ap_bonus NUMERIC := 0;
    
    -- Calculated attributes
    calculated_health NUMERIC;
    calculated_str NUMERIC;
    calculated_dex NUMERIC;
    calculated_int NUMERIC;
    calculated_con NUMERIC;
    calculated_enc NUMERIC;
    calculated_def NUMERIC;
    calculated_ap NUMERIC;
    
    -- Temporary variables
    current_item RECORD;
    affected_attribute TEXT;
    bonus_factor NUMERIC;
    items_weight NUMERIC;
    
    -- Health variables
    current_health NUMERIC;
    max_health NUMERIC;
    health_ratio NUMERIC;
BEGIN
    -- Get current health before changes
    SELECT health INTO current_health FROM characters WHERE id = character_id;
    
    -- Calculate max health using the function
    max_health := get_max_health(character_id);
    
    -- Calculate health ratio (current/max), clamp between 0 and 1
	health_ratio := GREATEST(LEAST(current_health / NULLIF(max_health, 0), 1), 0);    
    -- Get BASE attributes and MODIFIERS from class table
    SELECT 
        base_strength, base_dexterity, base_intelligence,
        base_constitution, base_action_points,
        strength_modifier, dexterity_modifier,
        intelligence_modifier, constitution_modifier, encumbrance_modifier,
        defence_modifier, ap_modifier
    INTO 
        class_base_str, class_base_dex, class_base_int,
        class_base_con, class_base_ap,
        class_str_mod, class_dex_mod,
        class_int_mod, class_con_mod, class_enc_mod,
        class_def_mod, class_ap_mod
    FROM classes
    WHERE id = (SELECT class_id FROM characters WHERE id = character_id);
    
    -- Calculate item bonuses (excluding HP)
    FOR current_item IN 
        SELECT im.affected_att, im.effect_factor 
        FROM character_inventory inv
        JOIN item_table i ON inv.item_id = i.id
		JOIN item_modifiers im ON im.item_id = i.id
        WHERE inv.owner_id = character_id
        AND im.affected_att != 'HP'
    LOOP
        affected_attribute := current_item.affected_att;
        bonus_factor := current_item.effect_factor;
        
        -- Add to the appropriate bonus variable
        CASE affected_attribute
            WHEN 'STR' THEN item_str_bonus := item_str_bonus + bonus_factor;
            WHEN 'DEX' THEN item_dex_bonus := item_dex_bonus + bonus_factor;
            WHEN 'INT' THEN item_int_bonus := item_int_bonus + bonus_factor;
            WHEN 'CON' THEN item_con_bonus := item_con_bonus + bonus_factor;
            WHEN 'DEF' THEN item_def_bonus := item_def_bonus + bonus_factor;
            WHEN 'AP' THEN item_ap_bonus := item_ap_bonus + bonus_factor;
            ELSE RAISE NOTICE 'Unknown attribute: %', affected_attribute;
        END CASE;
    END LOOP;

    -- Calculate effective attributes
    calculated_health := max_health * health_ratio; -- keeping health % over updates
    calculated_str := class_base_str + ((class_base_str * class_str_mod / 100) + item_str_bonus);
    calculated_dex := class_base_dex + ((class_base_dex * class_dex_mod / 100) + item_dex_bonus);
    calculated_int := class_base_int + ((class_base_int * class_int_mod / 100) + item_int_bonus);
    calculated_con := class_base_con + ((class_base_con * class_con_mod / 100) + item_con_bonus);
    
    -- Special calculations
    calculated_def := (calculated_int + calculated_con) * (class_def_mod / 100);
    
    -- AP calculation
    calculated_ap := class_base_ap + (((calculated_str + calculated_dex + calculated_int + calculated_con) / 4) * (class_ap_mod / 100) * health_ratio);
    
    -- Encumbrance calculation
    calculated_enc := (GREATEST(calculated_int, calculated_con) + GREATEST(calculated_dex, calculated_str));
	calculated_enc := calculated_enc + (calculated_enc * (class_enc_mod / 100));
    calculated_enc := calculated_enc - items_weight(character_id);
    
    IF calculated_enc < 0 THEN 
        RAISE NOTICE 'Character is over encumbered %', calculated_enc;
    END IF;

    -- Ensure minimum values
    calculated_health := ROUND(GREATEST(calculated_health, 1),2);
    calculated_str := ROUND(GREATEST(calculated_str, 1),2);
    calculated_dex := ROUND(GREATEST(calculated_dex, 1),2);
    calculated_int := ROUND(GREATEST(calculated_int, 1),2);
    calculated_con := ROUND(GREATEST(calculated_con, 1),2);
    calculated_enc := ROUND(GREATEST(calculated_enc, 0),2);
    calculated_def := ROUND(GREATEST(calculated_def, 0),2);
    calculated_ap := ROUND(GREATEST(calculated_ap, 0),2);

    -- Update character record with calculated values
    UPDATE characters SET
        health = calculated_health,
        strength = calculated_str,
        dexterity = calculated_dex,
        intelligence = calculated_int,
        constitution = calculated_con,
        encumbrance = calculated_enc,
        defence = calculated_def,
        action_points = calculated_ap
    WHERE id = character_id;
    
    RAISE NOTICE 'Updated attributes for character %', character_id;
END;
$$;
CREATE OR REPLACE PROCEDURE rest_character(p_char_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    last_position INT;
    last_change TIMESTAMP;
    current_health NUMERIC;
    max_health NUMERIC;
    seconds_rested NUMERIC;
    hours_rested NUMERIC;
    health_to_add NUMERIC;
BEGIN
    -- Get the most recent location change timestamp
    SELECT location_id, change_time
    INTO last_position, last_change
    FROM character_locations
    WHERE character_id = p_char_id
    ORDER BY change_time DESC
    LIMIT 1;

    -- Check if location data exists
    IF last_position IS NOT NULL THEN
        RAISE NOTICE 'Character % is already in battle %', p_char_id, last_position;
        RETURN;
    END IF;

    -- Get current and max health
    SELECT health, get_max_health(p_char_id)
    INTO current_health, max_health
    FROM characters
    WHERE id = p_char_id;

    -- Calculate exact seconds rested, then convert to fractional hours
    seconds_rested := EXTRACT(EPOCH FROM (NOW() - last_change));
    hours_rested := seconds_rested / 3600; 

    -- Calculate health to add (50% of max health per hour, capped at max health)
    health_to_add := LEAST(
        max_health * 0.5 * hours_rested,  -- 50% of max HP per hour (now works with fractional hours)
        max_health - current_health       -- Don't exceed max health
    );

    -- Update character health if they gained any
    IF health_to_add > 0 THEN
        UPDATE characters
        SET health = LEAST(current_health + health_to_add, max_health) WHERE id = p_char_id;
		-- REMOVE THESE
        RAISE NOTICE 'Character % rested for % hours (% minutes), gained % health (now %/% HP)',
            p_char_id,
            ROUND(hours_rested, 2),  -- Shows decimal hours (e.g., 0.50)
            ROUND(hours_rested * 60, 1),  -- Also shows minutes for clarity
            ROUND(health_to_add, 1),
            ROUND(LEAST(current_health + health_to_add, max_health), 1),
            ROUND(max_health, 1);
    ELSE
        RAISE NOTICE 'Character % is already at full health (%/% HP)',
            p_char_id,
            ROUND(current_health, 1),
            ROUND(max_health, 1);
    END IF;
END;
$$;
	