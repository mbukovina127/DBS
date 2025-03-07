select p.id, p.first_name, p.last_name, r1.period, r1.pctimestring as period_time from play_records r1
join players p on r1.player1_id = p.id
join play_records r2
on r1.game_id = r2.game_id
and r1.player1_id = r2.player1_id
and r1.event_msg_type = 'REBOUND'
and r2.event_msg_type = 'FIELD_GOAL_MADE'
AND r1.event_number = r2.event_number -1
order by r1.period ASC, r1.pctimestring DESC, p.id ASC