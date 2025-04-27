DROP TABLE IF EXISTS classes CASCADE;
DROP TABLE IF EXISTS characters CASCADE;
--
DROP TABLE IF EXISTS spell_table CASCADE;
DROP TABLE IF EXISTS spell_category CASCADE;
DROP TABLE IF EXISTS spell_modifiers CASCADE;
DROP TABLE IF EXISTS grimoire CASCADE;
--
DROP TABLE IF EXISTS item_table CASCADE;
DROP TABLE IF EXISTS character_inventory CASCADE;
DROP TABLE IF EXISTS item_modifiers CASCADE;
--
DROP TABLE IF EXISTS battle_log CASCADE;
DROP TABLE IF EXISTS battle_inventory CASCADE;
DROP TABLE IF EXISTS turn_log CASCADE;
DROP TABLE IF EXISTS battle_table CASCADE;
DROP TABLE IF EXISTS character_locations CASCADE;
--
--TABLES
--
--CHARACTERS
CREATE TABLE classes (
    id INT PRIMARY KEY,
    base_health NUMERIC NOT NULL,
    base_strength NUMERIC NOT NULL,
    base_dexterity NUMERIC NOT NULL,
    base_intelligence NUMERIC NOT NULL,
    base_constitution NUMERIC NOT NULL,
    base_action_points NUMERIC NOT NULL,
    health_modifier NUMERIC NOT NULL,
    strength_modifier NUMERIC NOT NULL,
    dexterity_modifier NUMERIC NOT NULL,
    intelligence_modifier NUMERIC NOT NULL,
    constitution_modifier NUMERIC NOT NULL,
    encumbrance_modifier NUMERIC NOT NULL,
    defence_modifier NUMERIC NOT NULL,
    ap_modifier NUMERIC NOT NULL
);
CREATE TABLE characters (
    id INT PRIMARY KEY,
    class_id INT REFERENCES classes(id),
    nickname TEXT NOT NULL,
    health NUMERIC,
    strength NUMERIC,
    dexterity NUMERIC,
    intelligence NUMERIC,
    constitution NUMERIC,
    encumbrance NUMERIC,
	defence NUMERIC,
    action_points NUMERIC
);
--SPELLS
create table spell_category (
	id SERIAL PRIMARY KEY,
	name TEXT not null,
	str_effect NUMERIC not null,
	dex_effect NUMERIC not null,
	int_effect NUMERIC not null
);
create table spell_table (
	id SERIAL PRIMARY KEY,
	class_id INT not null REFERENCES spell_category(id),
	name TEXT not null,
	base_ap_cost NUMERIC not null,
	base_damage NUMERIC not null,
	base_accuracy NUMERIC not null
);
create table spell_modifiers (
	spell_id INT not null REFERENCES spell_table(id),
	type TEXT not null,
	affected_att TEXT not null,
	effect_factor NUMERIC not null 	
);
create table grimoire (
	character_id INT not null REFERENCES characters(id),
	spell_id INT not null REFERENCES spell_table(id),
	PRIMARY KEY (character_id, spell_id)
);
--ITEMS
CREATE TABLE item_table (
	id SERIAL PRIMARY KEY,
	name TEXT not null,
	weight NUMERIC not null
);
CREATE TABLE character_inventory (
	item_id INT REFERENCES item_table(id),
	owner_id INT REFERENCES characters(id),
	quantity INT not null,
	PRIMARY KEY (owner_id, item_id)
);
CREATE TABLE item_modifiers (
	item_id INT REFERENCES item_table(id),
	affected_att TEXT not null,
	effect_factor NUMERIC not null
);
--COMBAT
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
    turn_id INT NOT NULL,
    character_id INT REFERENCES characters(id),
    target_id INT REFERENCES characters(id),
    item_id INT REFERENCES item_table(id),
    spell_id INT REFERENCES spell_table(id),
    action_type TEXT NOT NULL,
    ap_used NUMERIC NOT NULL,
    damage NUMERIC,
    log_time TIMESTAMP NOT NULL DEFAULT NOW()
);
--WORLD
CREATE TABLE character_locations (
    character_id INT NOT NULL REFERENCES characters(id),
    location_id INT,
    change_time TIMESTAMP NOT NULL DEFAULT NOW(),
    FOREIGN KEY (location_id) REFERENCES battle_table(id)
);

--
--INDEXES
--
--CHARACTERS
CREATE INDEX idx_characters_class_id ON characters(class_id); -- good for getting the class attributes
--SPELLS
CREATE INDEX idx_spell_modifiers_spell_id ON spell_modifiers(spell_id);
--INVENTORY AND ITEMS
CREATE INDEX idx_char_inv_owner_id ON character_inventory(owner_id);
CREATE INDEX idx_char_inv_item_id ON character_inventory(item_id);
CREATE INDEX idx_item_modifiers_item_id ON item_modifiers(item_id);
CREATE INDEX idx_bttl_inv_item_id ON battle_inventory(item_id);
CREATE INDEX idx_bttl_inv_battle_id ON battle_inventory(battle_id);
--BATTLE
CREATE INDEX idx_battle_log_battle_turn ON battle_log(battle_id, turn_id);
CREATE INDEX idx_battle_log_character_action ON battle_log(character_id, action_type);
CREATE INDEX idx_battle_log_turn_action ON battle_log(battle_id, turn_id, action_type);
CREATE INDEX idx_battle_log_target_damage ON battle_log(target_id, damage) WHERE damage IS NOT NULL;
--WORLD
CREATE INDEX idx_char_loc_battle_chars ON character_locations(location_id, character_id) WHERE location_id IS NOT NULL;
CREATE INDEX idx_char_loc_char_history ON character_locations(character_id, change_time DESC, location_id);

--
-- INSERTING
--
INSERT INTO classes (
    id,
    base_health,
    base_strength,
    base_dexterity,
    base_intelligence,
    base_constitution,
    base_action_points,
    health_modifier,
    strength_modifier,
    dexterity_modifier,
    intelligence_modifier,
    constitution_modifier,
    encumbrance_modifier,
    defence_modifier,
    ap_modifier
) VALUES
-- 1. Dreamwalker (balanced dream explorer)
(
    1,              -- id
    100,            -- base_health
    10,             -- base_strength
    12,             -- base_dexterity
    16,             -- base_intelligence
    12,             -- base_constitution
    8,              -- base_action_points
    10,             -- health_modifier (+10%)
    -5,             -- strength_modifier (-5%)
    15,             -- dexterity_modifier (+15%)
    20,             -- intelligence_modifier (+20%)
    0,              -- constitution_modifier (+0%)
    -10,            -- encumbrance_modifier (-10%)
    5,              -- defence_modifier (+5%)
    10              -- ap_modifier (+10%)
),

-- 2. Oneironaut (lucid dreaming specialist)
(
    2,
    80,
    8,
    14,
    20,
    10,
    10,
    -5,
    -10,
    5,
    30,
    -5,
    -15,
    0,
    15
),

-- 3. Nightmare Warden (dream protector)
(
    3,
    120,
    16,
    10,
    12,
    16,
    6,
    20,
    15,
    0,
    10,
    20,
    5,
    15,
    5
),

-- 4. Meditation Sage (focused discipline)
(
    4,
    90,
    6,
    16,
    18,
    14,
    12,
    5,
    -15,
    10,
    25,
    15,
    -20,
    10,
    20
);
INSERT INTO characters (
    id,
    class_id,
    nickname,
    health,
    strength,
    dexterity,
    intelligence,
    constitution,
    encumbrance,
	defence,
    action_points
) VALUES
-- Dreamwalker character
(
    1,
    1,
    'Lumen the Awake',
    NULL, 
    NULL, 
    NULL, 
    NULL, 
    NULL, 
    NULL, 
    NULL, 
    NULL  
),

-- Oneironaut character
(
    2,
    2,
    'Phantasos',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
),

-- Nightmare Warden character
(
    3,
    3,
    'Morpheus Guardian',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
),

-- Meditation Sage character
(
    4,
    4,
    'Zenith the Clear',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
);
--
INSERT INTO spell_category (name, str_effect, dex_effect, int_effect) VALUES
-- Warrior spells (strength focused)
('Physical', 0.2, 0.1, 0.0),    -- 1
-- Rogue spells (dexterity focused)
('Stealth', 0.0, 0.25, 0.05),  -- 2
-- Mage spells (intelligence focused)
('Magic', 0.0, 0.05, 0.3),   -- 3
-- Hybrid spells
('Hybrid', 0.1, 0.1, 0.1);    -- 4
INSERT INTO spell_table (class_id, name, base_ap_cost, base_damage, base_accuracy) VALUES
-- Warrior spells
(1, 'Crushing Blow', 3, 25, 80),      -- 1
(1, 'Cleave', 5, 40, 75),             -- 2
-- Rogue spells
(2, 'Precision Strike', 2, 15, 95),   -- 3
(2, 'Poison Dart', 4, 30, 85),        -- 4
-- Mage spells
(3, 'Fireball', 6, 50, 70),           -- 5
(3, 'Ice Shard', 4, 30, 90),          -- 6
-- Hybrid spells
(4, 'Arcane Slash', 5, 35, 85),       -- 7
(4, 'Nature''s Wrath', 7, 60, 65);    -- 8
INSERT INTO spell_modifiers (spell_id, type, affected_att, effect_factor) VALUES
-- Crushing Blow (strength boosts damage)
(1, 'DAMAGE', 'STR', 0.15),
-- Cleave (strength boosts damage, reduces cost)
(2, 'DAMAGE', 'STR', 0.2),
(2, 'COST', 'STR', -0.1),
-- Precision Strike (dexterity boosts accuracy)
(3, 'ACCURACY', 'DEX', 0.25),
-- Poison Dart (dexterity boosts damage)
(4, 'DAMAGE', 'DEX', 0.3),
-- Fireball (intelligence boosts damage)
(5, 'DAMAGE', 'INT', 0.4),
-- Ice Shard (intelligence reduces cost)
(6, 'COST', 'INT', -0.15),
-- Arcane Slash (strength and intelligence)
(7, 'DAMAGE', 'STR', 0.1),
(7, 'DAMAGE', 'INT', 0.1),
-- Nature's Wrath (all attributes)
(8, 'DAMAGE', 'STR', 0.05),
(8, 'DAMAGE', 'DEX', 0.05),
(8, 'DAMAGE', 'INT', 0.1);
INSERT INTO grimoire (character_id, spell_id) VALUES
-- Warrior character (ID 1)
(1, 1), (1, 2),
-- Rogue character (ID 2)
(2, 3), (2, 4),
-- Mage character (ID 3)
(3, 5), (3, 6),
-- Hybrid character (ID 4)
(4, 7), (4, 8),
-- Additional spells for variety
(1, 7),  -- Warrior with Arcane Slash
(2, 6),  -- Rogue with Ice Shard
(3, 4);  -- Mage with Poison Dart
--
INSERT INTO item_table (name, weight) VALUES
('Dreamcatcher Pendant', 0.3),
('Meditation Robe', 2.0),
('Incense of Clarity', 0.5),
('Astral Crystal', 1.0);
INSERT INTO character_inventory (item_id, owner_id, quantity) VALUES
(1, 1, 1),  -- Dreamcatcher Pendant
(2, 1, 1),  -- Meditation Robe
(3, 1, 3),  -- 3x Incense of Clarity
(4, 1, 1);  -- Astral Crystal
INSERT INTO item_modifiers (item_id, affected_att, effect_factor) VALUES
(1, 'INT', 8),       -- Dreamcatcher Pendant +8% intelligence
(2, 'DEF', 10),      -- Meditation Robe +10% defence
(3, 'AP', 5),        -- Incense of Clarity +5% action points
(4, 'HP', 12);       -- Astral Crystal +12% max health
--
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











