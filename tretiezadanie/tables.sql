-- CHARACTERS
CREATE TABLE classes (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    health_modifier NUMERIC not null,
    strength_modifier NUMERIC not null,
    dexterity_modifier NUMERIC not null,
    intelligence_modifier NUMERIC not null,
    constitution_modifier NUMERIC not null,
    encumbrance_modifier NUMERIC not null,
    defence_modifier NUMERIC not null,
    ap_modifier NUMERIC not null
);
CREATE TABLE characters (
    id SERIAL PRIMARY KEY,
    class_id INT not null REFERENCES classes(id),
    health NUMERIC not null,
    strength NUMERIC not null,
    dexterity NUMERIC not null,
    intelligence NUMERIC not null,
    constitution NUMERIC not null,
    action_points NUMERIC not null
);
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
-- SPELLS
create table spell_category (
	id SERIAL PRIMARY KEY,	
	str_effect NUMERIC,
	dex_effect NUMERIC,
	int_effect NUMERIC
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
	spell_id INT not null REFERENCES spell_category(id),
	affected_att TEXT not null,
	effect_factor NUMERIC not null 	
);
create table grimoire (
	character_id INT not null REFERENCES characters(id),
	spell_id INT not null REFERENCES spell_table(id)
);
--COMBAT
create table battle_table (
	id SERIAL PRIMARY KEY,
	started TIMESTAMP not null,
	finished TIMESTAMP
);
create table turn_log (
	id SERIAL PRIMARY KEY,
	battle_id INT not null REFERENCES battle_table(id) not null
);
create table battle_inventory (
	battle_id INT not null REFERENCES battle_table(id),
	turn_id INT not null REFERENCES turn_log(id),
	item_id INT not null REFERENCES item_table(id),
	quantity INT not null
);
create table battle_log (
	id SERIAL PRIMARY KEY,
	battle_id INT NOT NULL REFERENCES battle_table(id),
	character_id INT NOT NULL REFERENCES characters(id),
	target_id INT REFERENCES characters(id),
	item_id INT REFERENCES item_table(id),
	spell_id INT REFERENCES spell_table(id),
	action_type TEXT NOT NULL,
	ap_used NUMERIC NOT NULL,
	damage NUMERIC
);
--WORLD
create table character_locations (
	character_id INT not null REFERENCES characters(id),
	location_id INT REFERENCES battle_table(id),
	time TIMESTAMP
);