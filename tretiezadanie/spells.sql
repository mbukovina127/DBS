CREATE OR REPLACE FUNCTION effective_spell_stats(
    f_char_id INT,
    f_spell_id INT
)
RETURNS TABLE (
    final_damage NUMERIC,
    final_ap_cost NUMERIC,
    final_accuracy NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    base_ap NUMERIC;
    base_dmg NUMERIC;
    base_acc NUMERIC;
    char_str NUMERIC;
    char_dex NUMERIC;
    char_int NUMERIC;
    damage_mod NUMERIC := 0;
    cost_mod NUMERIC := 0;
    accuracy_mod NUMERIC := 0;
	mod_rec RECORD;
BEGIN
    -- Get base spell stats
    SELECT 
        base_ap_cost, 
        base_damage, 
        base_accuracy,
        name
    INTO 
        base_ap, 
        base_dmg, 
        base_acc
    FROM spell_table
    WHERE id = f_spell_id;

    -- Get character attributes
    SELECT 
        strength, dexterity, intelligence
    INTO 
        char_str, char_dex, char_int
    FROM characters
    WHERE id = f_char_id;

    -- Calculate modifiers by type
    FOR mod_rec IN 
        SELECT 
            type,
            affected_att, 
            effect_factor
        FROM spell_modifiers
        WHERE spell_id = f_spell_id
    LOOP
        -- Get attribute value
        DECLARE
            attr_val NUMERIC;
        BEGIN
            CASE mod_rec.affected_att
                WHEN 'STR' THEN attr_val := char_str;
                WHEN 'DEX' THEN attr_val := char_dex;
                WHEN 'INT' THEN attr_val := char_int;
                ELSE attr_val := 0;
            END CASE;

            -- Apply to correct modifier type
            CASE mod_rec.type
                WHEN 'DAMAGE' THEN 
                    damage_mod := damage_mod + (attr_val * mod_rec.effect_factor)/100;
                WHEN 'COST' THEN 
                    cost_mod := cost_mod + (attr_val * mod_rec.effect_factor)/100;
                WHEN 'ACCURACY' THEN 
                    accuracy_mod := accuracy_mod + (attr_val * mod_rec.effect_factor)/100;
            END CASE;
        END;
    END LOOP;
	
    -- Calculate final values
    final_damage := base_dmg + (base_dmg * damage_mod);
    final_ap_cost := GREATEST(base_ap + (base_ap * cost_mod), 1);
    final_accuracy := LEAST(base_acc + (base_acc * accuracy_mod), 95);
    RETURN NEXT;
END;
$$;
DROP PROCEDURE cast_spell CASCADE;
CREATE OR REPLACE PROCEDURE cast_spell(
    p_char_id INT,
    p_spell_id INT,
    p_target_id INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_battle_id INT;
    v_current_turn INT;
    v_has_spell BOOLEAN;
    v_spell_stats RECORD;
    v_current_ap NUMERIC;
    v_target_valid BOOLEAN;
    v_accuracy_roll NUMERIC;
    v_damage_dealt NUMERIC;
BEGIN
    -- Get battle ID from character's current location
    SELECT location_id INTO v_battle_id
    FROM character_locations
    WHERE character_id = p_char_id
    ORDER BY change_time DESC
    LIMIT 1;
    
    IF v_battle_id IS NULL THEN
        RAISE NOTICE 'Character % is not in a battle', p_char_id;
		RETURN;
    END IF;
    
    -- Get current turn ID
    SELECT MAX(turn_number) INTO v_current_turn
    FROM turn_log
    WHERE battle_id = v_battle_id;
        
    -- Check if character knows the spell
    SELECT EXISTS (
        SELECT 1 FROM grimoire 
        WHERE character_id = p_char_id AND spell_id = p_spell_id
    ) INTO v_has_spell;
    
    IF NOT v_has_spell THEN
        RAISE NOTICE 'Character % does not know spell %', p_char_id, p_spell_id;
		RETURN;
    END IF;
    
    -- Get spell stats
    SELECT * INTO v_spell_stats
    FROM effective_spell_stats(p_char_id, p_spell_id);
    
    -- Check character's AP
    SELECT action_points INTO v_current_ap
    FROM characters
    WHERE id = p_char_id;
    
    IF v_current_ap < v_spell_stats.final_ap_cost THEN
        RAISE NOTICE 'Not enough AP to cast spell (needs %, has %)', 
              v_spell_stats.final_ap_cost, v_current_ap;
		RETURN;
    END IF;
    
	IF p_target_id IS NOT NULL THEN
	    -- Check if target is in same battle and hasn't LEFT
	    SELECT EXISTS (
	        SELECT 1 FROM 
			(
				SELECT DISTINCT ON (character_id) 
				    character_id, 
				    location_id, 
				    change_time
				FROM character_locations
				ORDER BY character_id, change_time DESC			
			)
	        WHERE location_id = v_battle_id
	        AND character_id = p_target_id
	    ) INTO v_target_valid;
	    IF NOT v_target_valid THEN
	        RAISE NOTICE 'Target % is not a valid target in this battle', p_target_id;
			RETURN;
	    END IF;
	END IF;
    
    -- Accuracy check
    v_accuracy_roll := random() * 100;
    
    IF v_accuracy_roll > v_spell_stats.final_accuracy THEN
        -- Spell missed
        INSERT INTO battle_log (
            battle_id,
            turn_id,
            character_id,
            target_id,
            spell_id,
            action_type,
            ap_used,
            damage
        ) VALUES (
            v_battle_id,
            v_current_turn,
            p_char_id,
            p_target_id,
            p_spell_id,
            'MISS',
            v_spell_stats.final_ap_cost,
            0
        );
        
        RAISE NOTICE 'Spell missed! Rolled % (needed <= %)', 
              ROUND(v_accuracy_roll, 2), ROUND(v_spell_stats.final_accuracy, 2);
    ELSE
        -- Spell hit
        v_damage_dealt := v_spell_stats.final_damage;
        
        INSERT INTO battle_log (
            battle_id,
            turn_id,
            character_id,
            target_id,
            spell_id,
            action_type,
            ap_used,
            damage
        ) VALUES (
            v_battle_id,
            v_current_turn,
            p_char_id,
            p_target_id,
            p_spell_id,
            'CAST',
            v_spell_stats.final_ap_cost,
            v_damage_dealt
        );
        
        RAISE NOTICE 'Spell hit! Dealt % damage (rolled % <= %)', 
              v_damage_dealt, ROUND(v_accuracy_roll, 2), ROUND(v_spell_stats.final_accuracy, 2);
    END IF;
    
    -- Deduct AP
    UPDATE characters
    SET action_points = action_points - v_spell_stats.final_ap_cost
    WHERE id = p_char_id;
END;
$$;
