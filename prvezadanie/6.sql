select
	sid as season_id,
	round(avg(diff),2) as stability
from(select
		sid,
		gid,
		coalesce(abs(percentage - lag(percentage) over (partition by sid)), 0) as diff
	from (select
			sid,
			gid,
			count(CASE WHEN mt = 'FIELD_GOAL_MADE' and actor = pid then 1 else null end)* 100.0 
			/ count(CASE WHEN mt = 'FIELD_GOAL_MADE' and actor = pid or mt = 'FIELD_GOAL_MISSED' and actor = pid then 1 else null end)
			as percentage
		from (
			select 
				g.season_id sid,
				r.game_id gid,
				r.event_msg_type mt,
				r.player1_id actor,
				p.id pid
			from play_records r
			join players p on p.id in (r.player1_id, r.player2_id, r.player3_id)
			join games g on r.game_id = g.id
			where p.first_name = 'LeBron' and p.last_name = 'James'
			and season_type = 'Regular Season'
			and r.event_msg_type in ('FIELD_GOAL_MADE', 'FIELD_GOAL_MISSED')
			AND g.season_id IN (
			    SELECT g.season_id
			    FROM play_records r
			    JOIN games g ON r.game_id = g.id
			    JOIN players p ON p.id IN (r.player1_id, r.player2_id, r.player3_id)
			    WHERE p.first_name = 'LeBron' AND p.last_name = 'James'
			    AND g.season_type = 'Regular Season'
			    GROUP BY g.season_id
			    HAVING COUNT(DISTINCT r.game_id) > 49
				)
			) records
		group by sid, gid
		order by gid asc
		)
	)
group by sid 
order by avg(diff) asc, sid asc