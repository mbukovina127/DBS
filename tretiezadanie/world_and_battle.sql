-- Clean up existing tables
DROP TABLE IF EXISTS battle_log CASCADE;
DROP TABLE IF EXISTS battle_inventory CASCADE;
DROP TABLE IF EXISTS turn_log CASCADE;
DROP TABLE IF EXISTS battle_table CASCADE;
DROP TABLE IF EXISTS character_locations CASCADE;

-- COMBAT TABLES
CREATE TABLE battle_table (
    id SERIAL PRIMARY KEY,
    started TIMESTAMP NOT NULL DEFAULT NOW(),
    finished TIMESTAMP
);

CREATE TABLE turn_log (
    id SERIAL PRIMARY KEY,
    battle_id INT NOT NULL REFERENCES battle_table(id),
    turn_number INT NOT NULL
);

CREATE TABLE battle_inventory (
    battle_id INT NOT NULL REFERENCES battle_table(id),
    item_id INT NOT NULL REFERENCES item_table(id),
    quantity INT NOT NULL,
    PRIMARY KEY (battle_id, item_id)
);

CREATE TABLE battle_log (
    id SERIAL PRIMARY KEY,
    battle_id INT NOT NULL REFERENCES battle_table(id),
    turn_id INT NOT NULL REFERENCES turn_log(id),
    character_id INT REFERENCES characters(id),
    target_id INT REFERENCES characters(id),
    item_id INT REFERENCES item_table(id),
    spell_id INT REFERENCES spell_table(id),
    action_type TEXT NOT NULL,
    ap_used NUMERIC NOT NULL,
    damage NUMERIC,
    log_time TIMESTAMP NOT NULL DEFAULT NOW()
);

-- WORLD TABLE
CREATE TABLE character_locations (
    character_id INT NOT NULL REFERENCES characters(id),
    location_id INT,
    change_time TIMESTAMP NOT NULL DEFAULT NOW(),
    FOREIGN KEY (location_id) REFERENCES battle_table(id)
);

-- Sample data
INSERT INTO battle_table (started) VALUES 
    (NOW() - INTERVAL '1 hour'),
    (NOW() - INTERVAL '30 minutes');

INSERT INTO turn_log (battle_id, turn_number) VALUES
    (1, 1),
    (2, 1);

INSERT INTO character_locations (character_id, location_id, change_time) VALUES
    (1, NULL, NOW() - INTERVAL '2 hours'),  -- Healing zone
    (2, NULL, NOW() - INTERVAL '90 minutes'),
    (3, NULL, NOW() - INTERVAL '45 minutes'),  
    (4, NULL, NOW() - INTERVAL '15 minutes');
INSERT INTO battle_inventory (battle_id, item_id, quantity) VALUES
	(1, 1, 2),
	(1, 4, 5),
	(1, 2, 1);
-- Enter Combat Procedure
DROP PROCEDURE enter_combat cascade;
CREATE OR REPLACE PROCEDURE enter_combat(p_char_id INT, p_battle_id INT)
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
        p_battle_id,  -- Fixed: Use parameter instead of function reference
        current_turn,
        p_char_id,
        'JOINED',
        0  -- No AP cost to join
	);
	

	UPDATE CHARACTERS SET action_points = 0 WHERE id = p_char_id; -- setting action points to zero so the character can't do anything
	
    -- Update character location to the battle
    INSERT INTO character_locations (character_id, location_id)
    VALUES (p_char_id, p_battle_id);

    RAISE NOTICE 'Character % joined battle % on turn %', 
        p_char_id, p_battle_id, current_turn;  -- Fixed: Use parameter names
END;
$$;

-- call enter_combat(1,1);
-- select * from character_locations
-- order by character_id, change_time desc;
-- select * from battle_table bt
-- join turn_log tl on tl.battle_id = bt.id
-- join battle_log bl on bl.battle_id = bt.id and tl.turn_number = bl.turn_id;