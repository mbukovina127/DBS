SELECT
	-- *
	p.id,
	event_number,
	event_msg_type,
	score,
	score_margin,
		(CASE 
		    WHEN score_margin = 'TIE' THEN 0  -- Convert 'TIE' to 0
		    ELSE NULLIF(score_margin, '')::INTEGER  -- Convert numbers, ignore empty strings
		END) - 
	LAG(CASE 
	        WHEN score_margin = 'TIE' THEN 0  
	        ELSE NULLIF(score_margin, '')::INTEGER  
	    END) OVER (PARTITION BY r.game_id ORDER BY r.event_number) 
	AS diff
FROM play_records r
join players p
on p.id = r.player1_id or p.id = r.player2_id or p.id = r.player3_id
where r.game_id = 21701185 and score is not null
order by event_number asc
	