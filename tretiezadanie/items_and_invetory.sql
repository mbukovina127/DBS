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
