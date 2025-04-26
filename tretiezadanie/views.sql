CREATE OR REPLACE VIEW v_combat_state AS
SELECT tc.*, c.nickname,  c.action_points
FROM 
	(SELECT MAX(turn_number) as active_turn, c_now.character_id
	FROM (SELECT DISTINCT ON (character_id) 
						    character_id, 
						    location_id, 
						    change_time
		FROM character_locations
		ORDER BY character_id, change_time DESC) c_now
	JOIN turn_log tl on tl.battle_id = c_now.location_id
	where c_now.location_id is not null
	group by character_id) tc
JOIN characters c on tc.character_id = c.id;

CREATE OR REPLACE VIEW v_most_damage AS 
SELECT 
    cl.character_id,
    bl.battle_id,
    ROUND(SUM(bl.damage),2) AS total_damage_dealt
FROM 
    character_locations cl
JOIN 
    battle_log bl ON cl.character_id = bl.character_id AND bl.damage > 0  
WHERE 
    cl.location_id IS NOT NULL 
GROUP BY 
    cl.character_id, 
    bl.battle_id
ORDER BY 
    total_damage_dealt DESC; 

CREATE OR REPLACE VIEW v_strongest_characters AS
SELECT 
    c.id,
    c.nickname,
    c.health,
	c.defence,
    (SELECT COALESCE(ROUND(SUM(damage),2), 0) FROM battle_log WHERE character_id = c.id) AS total_damage_dealt,
    (SELECT COUNT(DISTINCT battle_id) FROM battle_log WHERE character_id = c.id) AS battles_fought,
    (SELECT COUNT(*) FROM battle_log WHERE character_id = c.id AND action_type = 'DIED') AS deaths
FROM characters c
ORDER BY 
    total_damage_dealt DESC, health DESC, defence DESC, deaths ASC;

CREATE OR REPLACE VIEW v_combat_damage AS
SELECT bl.battle_id, bl.turn_id as turn_number, COALESCE(SUM(damage),0) as damage_output
FROM battle_log bl
GROUP BY bl.battle_id, bl.turn_id
ORDER by bl.battle_id ASC, bl.turn_id ASC;

CREATE OR REPLACE VIEW v_spell_statistics AS
SELECT 
    st.id AS spell_id,
    st.name AS spell_name,
    sc.id AS category_id,
    COUNT(bl.id) AS times_cast,
    SUM(CASE WHEN bl.action_type = 'MISS' THEN 1 ELSE 0 END) AS times_missed,
    COALESCE(SUM(bl.damage), 0) AS total_damage,
    AVG(CASE WHEN bl.action_type = 'CAST' THEN bl.damage ELSE NULL END)::NUMERIC(10,2) AS avg_damage,
	st.base_damage,
	st.base_ap_cost,
	st.base_accuracy
FROM spell_table st
JOIN spell_category sc ON st.class_id = sc.id
LEFT JOIN battle_log bl ON st.id = bl.spell_id
GROUP BY st.id, sc.id
ORDER BY total_damage DESC;