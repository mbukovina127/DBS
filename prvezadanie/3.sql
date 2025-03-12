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
		COALESCE(SUM(diff), 0) as points,
		COALESCE(count(case when diff = 2 then 1 else null end), 0) as TWOPM,
		COALESCE(count(case when diff = 3 then 1 else null end), 0) as THREEPM,
		COALESCE(count(case when f.event_msg_type = 'FIELD_GOAL_MISSED' then 1 else null end), 0) as missed_shots,
		COALESCE(count(case when f.event_msg_type = 'FREE_THROW' then diff else null end), 0) as FTM,
		COALESCE(count(case when f.event_msg_type = 'FREE_THROW' and diff is null then 1 else null end), 0) as missed_free_throws	
	from
		(select 
			r.player1_id,
			r.event_msg_type,
			diff
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
			and score is not null
			order by event_number asc
			) as pts -- vybrane kose a free throws za kolko bodov
		right join play_records r
		on pts.event_number = r.event_number
		WHERE r.event_msg_type in ('FREE_THROW', 'FIELD_GOAL_MADE', 'FIELD_GOAL_MISSED')
		and r.game_id = 21701185
		) as f -- vybrane vsetky eventy RIGHT JOIN
	right join ( -- vyber vsetkych hracov co nieco spravili v hre
		select player1_id as pid from play_records r
		where r.game_id = 21701185
		union
		select player2_id as pid from play_records r
		where r.game_id = 21701185
		union
		select player3_id as pid from play_records r
		where r.game_id = 21701185
	) ap
	on ap.pid = player1_id -- prirad vsetky akcie k hracom co nieco spravili v pripade null ak ziadne skore
	join players p
	on p.id = ap.pid
	group by p.id, p.first_name, p.last_name
	order by points desc
	) l