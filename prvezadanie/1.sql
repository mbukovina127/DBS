with records as (
	select 
		*
	from (select 
			r.event_number,
			r.pctimestring,
			r.period,
			r.event_msg_type,
			lag(r.event_msg_type) over (partition by r.game_id order by r.event_number asc) as prev_msg_type,
			r.player1_id,
			lag(r.player1_id) over (partition by r.game_id order by r.event_number asc) as prev_player
		from play_records r
		where r.game_id = 22000529)
	where player1_id = prev_player
	and event_msg_type = 'FIELD_GOAL_MADE'
	and prev_msg_type = 'REBOUND'
)

select 
	p.id, 
	p.first_name, 
	p.last_name, 
	r.period, 
	r.pctimestring as period_time 
from records r
join players p on r.player1_id = p.id
order by r.period ASC, r.pctimestring::TIME DESC, p.id ASC