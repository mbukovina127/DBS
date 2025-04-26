CREATE OR REPLACE VIEW v_combat_state AS
WITH current_turn AS (
    SELECT 
        bt.id AS battle_id,
        bt.started,
        MAX(tl.turn_number) AS current_turn_number,
        MAX(tl.id) AS current_turn_id
    FROM battle_table bt
    JOIN turn_log tl ON bt.id = tl.battle_id
    WHERE bt.finished IS NULL
    GROUP BY bt.id
),
active_characters AS (
    SELECT DISTINCT 
        cl.character_id,
        cl.location_id AS battle_id
    FROM character_locations cl
    WHERE cl.location_id IN (SELECT battle_id FROM current_turn)
)
-- Current turn data (full details)
SELECT 
    ct.battle_id,
    ct.started,
    ct.current_turn_number AS turn_number,
    c.id AS character_id,
    c.nickname,
    c.action_points AS remaining_ap,
    cl.location_id,
    'CURRENT' AS turn_type
FROM current_turn ct
JOIN active_characters ac ON ct.battle_id = ac.battle_id
JOIN characters c ON ac.character_id = c.id
JOIN character_locations cl ON c.id = cl.character_id AND cl.location_id = ct.battle_id

UNION ALL

-- Last turn data (limited details)
SELECT 
    ct.battle_id,
    NULL AS started,  -- Null for previous turn
    ct.current_turn_number - 1 AS turn_number,
    c.id AS character_id,
    NULL AS nickname,  -- Null for previous turn
    c.action_points AS remaining_ap,
    NULL AS location_id,  -- Null for previous turn
    'PREVIOUS' AS turn_type
FROM current_turn ct
JOIN battle_log bl ON ct.battle_id = bl.battle_id 
    AND bl.turn_id = (SELECT id FROM turn_log 
                     WHERE battle_id = ct.battle_id 
                     AND turn_number = ct.current_turn_number - 1)
JOIN characters c ON bl.character_id = c.id
WHERE bl.action_type NOT IN ('LEFT', 'DIED');

-- MOST DAMGE
CREATE OR REPLACE VIEW v_most_damage AS
SELECT 
    c.id AS character_id,
    c.nickname,
    COALESCE(ROUND(SUM(bl.damage),2), 0) AS total_damage
FROM characters c
LEFT JOIN battle_log bl ON c.id = bl.character_id AND bl.damage > 0
GROUP BY c.id
ORDER BY total_damage DESC;

-- STRONGEST CHARACTER
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
    total_damage_dealt DESC,
    health DESC,
	defence DESC,
    deaths ASC;

-- SPELL STATISTICS
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