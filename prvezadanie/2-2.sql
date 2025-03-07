-- select f.id as player_id, f.first_name, f.last_name, f.team_id, f.PPG
select p.id, p.full_name, team_id, count(team_id) over (partition by p.id) as team_changes from players p
join (
	select game_id, season_id, player1_id as player_id, player1_team_id as team_id, event_msg_type from play_records pr1
	join games g on game_id = g.id
	where g.season_id = '22017'
	
	union
	
	select game_id, season_id, player1_id as player_id, player1_team_id as team_id, event_msg_type from play_records pr2
	join games g on game_id = g.id
	where g.season_id = '22017'
	
) pr
on pr.player_id = p.id
where event_msg_type in ('FREE_THROW', 'FIELD_GOAL_MADE', 'FIELD_GOAL_MISSED', 'REBOUND')
order by team_changes desc
limit 5

