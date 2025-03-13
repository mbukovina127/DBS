select 
	*
from (
	select
		l.player_id,
		l.first_name,
		l.last_name,
		l.points,
		l.TWOPM,
		l.THREEPM,
		l.missed_shots,
		ROUND(COALESCE(((l.TWOPM + l.THREEPM) * 100.0 / NULLIF((l.TWOPM + l.THREEPM + l.missed_shots), 0)),0), 2) AS shooting_percentage,
		l.FTM,
		l.missed_free_throws,
		ROUND(COALESCE((l.FTM) * 100.0 / NULLIF((l.FTM + l.missed_free_throws), 0),0), 2) as FT_percentage
	from
		(
		select
			p.id as player_id,
			p.first_name,
			p.last_name,
			COALESCE(SUM(case when p.id = f.player1_id then diff else null end), 0) as points,
			COALESCE(count(case when diff = 2 and p.id = f.player1_id then 1 else null end), 0) as TWOPM,
			COALESCE(count(case when diff = 3 and p.id = f.player1_id then 1 else null end), 0) as THREEPM,
			COALESCE(count(case when f.event_msg_type = 'FIELD_GOAL_MISSED' and p.id = f.player1_id then 1 else null end), 0) as missed_shots,
			COALESCE(count(case when f.event_msg_type = 'FREE_THROW' and p.id = f.player1_id then diff else null end), 0) as FTM,
			COALESCE(count(case when f.event_msg_type = 'FREE_THROW' and p.id = f.player1_id and diff is null then 1 else null end), 0) as missed_free_throws	
		from
			(select 
				r.player1_id,
				r.player2_id,
				r.player3_id,
				r.event_msg_type,
				diff,
				r.event_number
			from 
				(SELECT
					event_number,
					event_msg_type,
					score,
					score_margin,
					ABS((CASE 
						WHEN score_margin = 'TIE' THEN 0
						ELSE NULLIF(score_margin, '')::INTEGER
					END) - 
					( CASE WHEN LAG(CASE 
					        WHEN score_margin = 'TIE' THEN 0  
					        ELSE score_margin::INTEGER  
					    END) OVER (PARTITION BY r.game_id ORDER BY r.event_number) is null then 0 
						else LAG(CASE 
					        WHEN score_margin = 'TIE' THEN 0  
					        ELSE score_margin::INTEGER  
					    END) OVER (PARTITION BY r.game_id ORDER BY r.event_number)
						end))
					AS diff
				FROM play_records r
				where r.game_id = 21701185 
				and score_margin is not null
				order by event_number asc
				) as pts -- vybrane kose a free throws za kolko bodov
			right join play_records r
			on pts.event_number = r.event_number
			WHERE r.event_msg_type in ('FREE_THROW', 'FIELD_GOAL_MADE', 'FIELD_GOAL_MISSED')
			and r.game_id = 21701185
			order by r.event_number
			) as f -- vybrane vsetky eventy RIGHT JOIN
		join players p
		on p.id in (f.player1_id, f.player2_id, f.player3_id)
		group by p.id, p.first_name, p.last_name
	) l ) p
order by points desc, shooting_percentage desc, FT_percentage desc, player_id asc

-- duplikatne zaznamy
-- select *
-- from play_records r 
-- where 202328 = r.player1_id
-- and 21701185 = r.game_id
-- and r.event_msg_type in ('FREE_THROW', 'FIELD_GOAL_MADE', 'FIELD_GOAL_MISSED')
-- order by r.event_msg_type, r.event_number

-- select *
-- from play_records r 
-- -- where 202328 = r.player1_id
-- where 21701185 = r.game_id
-- order by r.event_number