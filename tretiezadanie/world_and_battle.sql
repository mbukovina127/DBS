DROP PROCEDURE IF EXISTS enter_battle CASCADE;
DROP PROCEDURE IF EXISTS reset_round cascade;

CREATE OR REPLACE PROCEDURE enter_battle(p_char_id INT, p_battle_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    current_turn INT;
    healing_zone BOOLEAN;
    battle_status TIMESTAMP;
BEGIN
    -- Check battle status
    SELECT finished INTO battle_status
    FROM battle_table
    WHERE id = p_battle_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Battle % does not exist', p_battle_id;
    ELSIF battle_status IS NOT NULL THEN
        RAISE EXCEPTION 'Battle % has already ended', p_battle_id;
    END IF;

    -- Check if character is in healing zone
    SELECT location_id IS NULL 
    INTO healing_zone
    FROM character_locations
    WHERE character_id = p_char_id
    ORDER BY change_time DESC
    LIMIT 1;

    -- Rest character if coming from healing zone
    IF healing_zone THEN
        CALL rest_character(p_char_id);
	ELSE
		RAISE EXCEPTION 'Character % must be in a healing zone (null location) to join battle', p_char_id;
    END IF;

    -- Get current turn number for the battle
    SELECT MAX(turn_number) INTO current_turn
    FROM turn_log
    WHERE battle_id = p_battle_id;

    -- Insert JOIN action into battle log
    INSERT INTO battle_log (
        battle_id,
        turn_id,
        character_id,
        action_type,
        ap_used
    ) VALUES (
        p_battle_id,
        current_turn,
        p_char_id,
        'JOINED',
        0  -- No AP cost to join
	);
	
	CALL update_character_attributes(p_char_id);

	UPDATE CHARACTERS SET action_points = 0 WHERE id = p_char_id; -- setting action points to zero so the character can't do anything
	
    -- Update character location to the battle
    INSERT INTO character_locations (character_id, location_id)
    VALUES (p_char_id, p_battle_id);

    RAISE NOTICE 'Character % joined battle % on turn %', 
        p_char_id, p_battle_id, current_turn; 
END;
$$;
CREATE OR REPLACE PROCEDURE reset_round(p_battle_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_turn INT;
    v_character_id INT;
    v_damage_received NUMERIC;
    v_current_health NUMERIC;
    v_leave_chance NUMERIC;
    v_left BOOLEAN;
    v_item_id INT;
    v_quantity INT;
	v_number_of_players INT;
BEGIN
	IF NOT EXISTS (SELECT 1 FROM battle_table WHERE id = p_battle_id) THEN
        RAISE EXCEPTION 'Battle with ID % does not exist', p_battle_id;
    END IF;
	
    -- Get current turn number
    SELECT MAX(turn_number) INTO v_current_turn
    FROM turn_log
    WHERE battle_id = p_battle_id;

	SELECT COUNT(distinct character_id) into v_number_of_players
	from battle_log bl where bl.battle_id = p_battle_id and bl.turn_id = v_current_turn;
    
    -- Process characters who tried to leave (actions with type 'FLEE')
    FOR v_character_id IN (
        SELECT DISTINCT character_id 
        FROM battle_log 
        WHERE battle_id = p_battle_id 
        AND turn_id = v_current_turn
        AND action_type = 'FLEE'
    ) LOOP
        -- chance to leave
        v_leave_chance := random();
        v_left := (v_leave_chance > (GREATEST(1 - v_number_of_players/5.0), 0.1)); -- CHANGE TO FUNCTION I HAVE SPECIFIED
        
        IF v_left THEN
            -- Log successful leave
            INSERT INTO battle_log (
                battle_id,
                turn_id,
                character_id,
                action_type,
                ap_used
            ) VALUES (
                p_battle_id,
                v_current_turn,
                v_character_id,
                'LEFT',
                0
            );
            
            -- Update character location to healing zone (NULL)
            INSERT INTO character_locations (character_id, location_id)
            VALUES (v_character_id, NULL);
            
            RAISE NOTICE 'Character % successfully fled battle %', v_character_id, p_battle_id;
        ELSE
            RAISE NOTICE 'Character % failed to flee battle %', v_character_id, p_battle_id;
        END IF;
    END LOOP;
    -- Process damage and check for deaths 
    FOR v_character_id IN (
	    SELECT DISTINCT bl.character_id
	    FROM battle_log bl
	    JOIN (
	        SELECT DISTINCT ON (character_id)
	            character_id,
	            location_id,
	            change_time
	        FROM character_locations
	        ORDER BY character_id, change_time DESC
	    ) latest_loc ON bl.character_id = latest_loc.character_id
	    WHERE latest_loc.location_id = p_battle_id 
	    AND bl.character_id IS NOT NULL
	    AND bl.battle_id = p_battle_id  
    ) LOOP
        -- Sum all damage received by this character
        SELECT COALESCE(SUM(damage), 0) INTO v_damage_received
        FROM battle_log
        WHERE battle_id = p_battle_id
        AND turn_id = v_current_turn
        AND target_id = v_character_id
        AND damage > 0;
		
        -- Apply damage
        UPDATE characters
        SET health = GREATEST(health - v_damage_received, 0)
        WHERE id = v_character_id
        RETURNING health INTO v_current_health;
        
        -- Check for death
        IF v_current_health <= 0 THEN
            -- Move items to battle inventory
            FOR v_item_id, v_quantity IN (
			    SELECT item_id, quantity 
			    FROM character_inventory
			    WHERE owner_id = v_character_id
			) LOOP
			    -- Check if item already exists in battle inventory
			    IF EXISTS (
			        SELECT 1 FROM battle_inventory
			        WHERE battle_id = p_battle_id
			        AND item_id = v_item_id
			    ) THEN
			        -- Update existing item quantity
			        UPDATE battle_inventory
			        SET quantity = quantity + v_quantity
			        WHERE battle_id = p_battle_id
			        AND item_id = v_item_id;
			    ELSE
			        -- Insert new item
			        INSERT INTO battle_inventory (
			            battle_id,
			            item_id,
			            quantity
			        ) VALUES (
			            p_battle_id,
			            v_item_id,
			            v_quantity
			        );
			    END IF;
			END LOOP;
            
            -- Clear character inventory
            DELETE FROM character_inventory WHERE owner_id = v_character_id;
            
            -- Log death
            INSERT INTO battle_log (
                battle_id,
                turn_id,
                character_id,
                action_type,
                ap_used
            ) VALUES (
                p_battle_id,
                v_current_turn,
                v_character_id,
                'DIED',
                0
            );
            
            -- Move to healing zone (NULL location)
            INSERT INTO character_locations (character_id, location_id)
            VALUES (v_character_id, NULL);
            
            RAISE NOTICE 'Character % has died in battle %', v_character_id, p_battle_id;
        END IF;
    END LOOP;
    
    -- Process successful loot actions
    FOR v_character_id, v_item_id IN (
        SELECT bl.character_id, bl.item_id
        FROM battle_log bl
        WHERE bl.battle_id = p_battle_id
        AND bl.turn_id = v_current_turn
        AND bl.action_type = 'LOOT'
        -- Only process if looter is still alive
        AND EXISTS (
            SELECT 1 FROM characters 
            WHERE id = bl.character_id AND health > 0
        )
    ) LOOP
        CALL loot_item(v_character_id, v_item_id);
    END LOOP;
    
    -- Log end of round
    INSERT INTO battle_log (
        battle_id,
        turn_id,
        action_type,
        ap_used
    ) VALUES (
        p_battle_id,
        v_current_turn,
        'END',
        0
    );
    
    -- Update attributes for all surviving characters
    FOR v_character_id IN (
		SELECT DISTINCT bl.character_id
	    FROM battle_log bl
	    JOIN (
	        SELECT DISTINCT ON (character_id)
	            character_id,
	            location_id,
	            change_time
	        FROM character_locations
	        ORDER BY character_id, change_time DESC
	    ) latest_loc ON bl.character_id = latest_loc.character_id
	    WHERE latest_loc.location_id = p_battle_id 
	    AND bl.character_id IS NOT NULL
	    AND bl.battle_id = p_battle_id  
    ) LOOP
        CALL update_character_attributes(v_character_id);
    END LOOP;

    RAISE NOTICE 'Round % completed for battle %', v_current_turn, p_battle_id;
	-- Create new turn
    INSERT INTO turn_log (battle_id, turn_number)
    VALUES (p_battle_id, v_current_turn+1);
END;
$$;