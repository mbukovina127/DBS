SELECT
	*
	-- p.id,
	-- event_number,
	-- event_msg_type,
	-- SPLIT_PART(score, '-', 1) as left_score,
	-- SPLIT_PART(score, '-', 2) as right_score,
FROM play_records r
join players p
on p.id = r.player1_id or p.id = r.player2_id or p.id = r.player3_id
where r.game_id = 21701185 and score is not null
order by event_number asc
	