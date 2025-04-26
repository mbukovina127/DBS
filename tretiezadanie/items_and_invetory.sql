DROP TABLE IF EXISTS item_table CASCADE;
DROP TABLE IF EXISTS character_inventory CASCADE;
DROP TABLE IF EXISTS item_modifiers CASCADE;
-- ITEMS
CREATE TABLE item_table (
	id SERIAL PRIMARY KEY,
	name TEXT not null,
	weight NUMERIC not null
);
CREATE TABLE character_inventory (
	item_id INT REFERENCES item_table(id),
	owner_id INT REFERENCES characters(id),
	quantity INT not null
);
CREATE TABLE item_modifiers (
	item_id INT REFERENCES item_table(id),
	affected_att TEXT not null,
	effect_factor NUMERIC not null
);
-- Additional items
INSERT INTO item_table (name, weight) VALUES
('Dreamcatcher Pendant', 0.3),
('Meditation Robe', 2.0),
('Incense of Clarity', 0.5),
('Astral Crystal', 1.0);

-- Inventory for character with ID 2
INSERT INTO character_inventory (item_id, owner_id, quantity) VALUES
(1, 1, 1),  -- Dreamcatcher Pendant
(2, 1, 1),  -- Meditation Robe
(3, 1, 3),  -- 3x Incense of Clarity
(4, 1, 1);  -- Astral Crystal

-- Modifiers for new items
INSERT INTO item_modifiers (item_id, affected_att, effect_factor) VALUES
(1, 'INT', 8),       -- Dreamcatcher Pendant +8% intelligence
(2, 'DEF', 10),      -- Meditation Robe +10% defence
(3, 'AP', 5),        -- Incense of Clarity +5% action points
(4, 'HP', 12);       -- Astral Crystal +12% max health

DROP PROCEDURE queue_loot_item cascade;
CREATE OR REPLACE PROCEDURE queue_loot_item(
    char_id INT,
    p_item_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
	current_battle INT;
	current_turn INT;
	quantity INT;
	ap NUMERIC;
BEGIN 
	SELECT location_id into current_battle
	FROM character_locations cl
	WHERE cl.character_id = char_id
	ORDER BY change_time DESC
	LIMIT 1;

	IF current_battle IS NULL THEN
		RAISE NOTICE 'Character is not in batlle';
		RETURN;
	END IF;

	SELECT MAX(turn_number) INTO current_turn 
	FROM turn_log tl
	where tl.battle_id = current_battle;

	SELECT bi.quantity INTO quantity FROM battle_inventory bi where bi.battle_id = current_battle and bi.item_id = p_item_id;

	IF NOT FOUND THEN
		RAISE NOTICE 'Item isnt on the battlefield';
		RETURN;
	END IF;
	
	SELECT action_points into ap from characters c where c.id = char_id;

	ap := ap - 1; -- looting costs one action point

	IF ap < 0 THEN 
		RAISE NOTICE 'Character doesnt have enough action points';
		RETURN;
	END IF;
	
	UPDATE characters SET action_points = ap WHERE id = char_id;
	
	INSERT INTO battle_log (
        battle_id,
		turn_id,
        character_id,
        item_id,
        action_type,
        ap_used
    )
    VALUES (
        current_battle,
		current_turn,
        char_id,
        p_item_id,
        'LOOT',
        1
    );
END;
$$;
DROP PROCEDURE loot_item cascade;
CREATE OR REPLACE PROCEDURE loot_item(
    char_id INT,
    p_item_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    loot_roll NUMERIC;
    item_quantity INT;
    existing_quantity INT;
	current_battle INT;
	current_turn INT;
BEGIN
	SELECT location_id into current_battle
	FROM character_locations cl
	WHERE cl.character_id = 1
	ORDER BY change_time DESC
	LIMIT 1;

	IF current_battle IS NULL THEN
		RAISE NOTICE 'Character is not in batlle';
		RETURN;
	END IF;
	
    -- Roll 50% chance for success (random() returns 0.0 <= x < 1.0)
    loot_roll := random();
    
    IF loot_roll < 0.2 THEN
        RAISE NOTICE 'Loot attempt failed (rolled % < 0.2)', loot_roll;
        RETURN;
    END IF;

    -- Check if item exists in battle inventory
    SELECT quantity INTO item_quantity
    FROM battle_inventory
    WHERE battle_id = current_battle
      AND item_id = p_item_id
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE NOTICE 'Item % not found in battle %', p_item_id, current_battle;
        RETURN;
    END IF;

    -- Handle item quantity (decrease or remove)
    IF item_quantity > 1 THEN
        UPDATE battle_inventory
        SET quantity = quantity - 1
        WHERE battle_id = current_battle
          AND item_id = p_item_id;
    ELSE
        DELETE FROM battle_inventory
        WHERE battle_id = current_battle
          AND item_id = p_item_id;
    END IF;

    -- Check if character already has this item
    SELECT quantity INTO existing_quantity
    FROM character_inventory
    WHERE owner_id = char_id
      AND item_id = p_item_id
    LIMIT 1;

    -- Add to character inventory
    IF FOUND THEN
        UPDATE character_inventory
        SET quantity = quantity + 1
        WHERE owner_id = char_id
	  	AND item_id = p_item_id;
    ELSE
        INSERT INTO character_inventory (owner_id, item_id, quantity)
        VALUES (char_id, p_item_id, 1);
    END IF;

    RAISE NOTICE 'Character % successfully looted item % from battle %',
        char_id, p_item_id, current_battle;

	-- Get current turn 
	select max(turn_number) into current_turn from turn_log tl where tl.battle_id = current_battle;
    -- Log the loot action
    INSERT INTO battle_log (
        battle_id,
		turn_id,
        character_id,
        item_id,
        action_type,
        ap_used
    )
    VALUES (
        current_battle,
		current_turn,
        char_id,
        p_item_id,
        'LOOTED',
        0
    );
END;
$$;
