
select id, full_name, team_changes from players
JOIN (
    SELECT 
        player_id, 
        COUNT(distinct team_id) as team_changes
    FROM (
        SELECT 
            player1_id AS player_id, 
            player1_team_id AS team_id
        FROM play_records r
        JOIN games g ON r.game_id = g.id
        WHERE g.season_id = '22017' 
            AND r.player1_id IS NOT NULL
            AND r.event_msg_type IN ('FREE_THROW', 'FIELD_GOAL_MADE', 'FIELD_GOAL_MISSED', 'REBOUND')
        UNION
        SELECT 
            player2_id AS player_id, 
            player2_team_id AS team_id
        FROM play_records r
        JOIN games g ON r.game_id = g.id
        WHERE g.season_id = '22017' 
            AND r.player2_id IS NOT NULL
            AND r.event_msg_type IN ('FREE_THROW', 'FIELD_GOAL_MADE', 'FIELD_GOAL_MISSED', 'REBOUND')
    ) AS player_teams
	group by player_id
	order by team_changes desc
	limit 5
) pr ON pr.player_id = id
order by id



