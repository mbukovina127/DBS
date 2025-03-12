select 
	*
from 
games

SELECT
	season_id,
	count( g.id)
FROM 
	(
		select 
			g.season_id,
			count(distinct r.game_id)
		from play_records r
		join players p on p.id in (r.player1_id, r.player2_id, r.player3_id)
		join games g on g.id = r.game_id
		where p.first_name = 'LeBron' and p.last_name  = 'James'
		group by g.season_id
		having count(distinct r.game_id) > 50
	)
group by season_id
order by count(g.id) desc