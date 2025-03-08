SELECT 
    p.id AS player_id,
    p.first_name,
    p.last_name,
    t.id,
    t.full_name AS team_name,
    
	SUM(CASE WHEN pr.event_msg_type = 'FIELD_GOAL_MADE' THEN 2 ELSE NULL END) 
          / COUNT(DISTINCT pr.game_id) 
		  AS PPG,
    SUM(CASE 
			WHEN pr.event_msg_type = 'FIELD_GOAL_MADE' and pr.player2_id = p.id
			THEN 1 
			ELSE NULL END) 
	  / COUNT(DISTINCT pr.game_id)
	  AS APG,
    COUNT(DISTINCT pr.game_id) AS games
FROM play_records pr
JOIN games g ON pr.game_id = g.id
JOIN players p ON pr.player1_id = p.id OR pr.player2_id = p.id
JOIN teams t ON pr.player1_team_id = t.id or pr.player2_team_id = t.id
WHERE g.season_id = '22017'
AND pr.event_msg_type IN ('FREE_THROW', 'FIELD_GOAL_MADE', 'FIELD_GOAL_MISSED', 'REBOUND')
AND p.id IN (
    SELECT player_id
    FROM (
        SELECT player1_id AS player_id, player1_team_id AS team_id FROM play_records pr1
        JOIN games g1 ON pr1.game_id = g1.id
        WHERE g1.season_id = '22017'
        AND pr1.event_msg_type IN ('FREE_THROW', 'FIELD_GOAL_MADE', 'FIELD_GOAL_MISSED', 'REBOUND')
        
        UNION ALL
        
        SELECT player2_id AS player_id, player2_team_id AS team_id FROM play_records pr2
        JOIN games g2 ON pr2.game_id = g2.id
        WHERE g2.season_id = '22017'
        AND pr2.event_msg_type IN ('FREE_THROW', 'FIELD_GOAL_MADE', 'FIELD_GOAL_MISSED', 'REBOUND')
    ) AS player_teams
    GROUP BY player_id
    HAVING COUNT(DISTINCT team_id) > 1
    ORDER BY COUNT(DISTINCT team_id) DESC
    LIMIT 5
)
GROUP BY p.id, p.first_name, p.last_name, t.id, t.full_name
ORDER BY p.id ASC, t.id ASC;
