with streaks as (select grps.id,
		-- points, assists, rbds, 
		-- double, blocks
		count(blocks) as streaks
from 	(select scr.*,
			sum(case when double_triple = false then 1 else 0 end) over (partition by scr.id order by scr.game_id asc) as blocks
		from(
				select 
				scr.game_id, scr.id,
				scr.points,
				-- lag(scr.points) over (partition by scr.id order by scr.game_id asc) as prev_p,
				scr.assists,
				-- lag(scr.assists) over (partition by scr.id order by scr.game_id asc) as prev_a,
				scr.rbds,
				-- lag(scr.rbds) over (partition by scr.id order by scr.game_id asc) as prev_r,
				(scr.points > 9 and scr.assists > 9 and scr. rbds > 9) as double_triple
				-- coalesce((scr.points > 9 and scr.assists > 9 and scr. rbds > 9 and (lag(case when scr.points > 9 and scr.assists > 9 and scr.rbds > 9 then 1 else null end) over (partition by scr.id order by scr.game_id asc)) = 1)
				-- ,scr.points > 9 and scr.assists > 9 and scr. rbds > 9) as double
			from (select 
					r.game_id,
					p.id,
					sum(case 	when event_msg_type = 'FIELD_GOAL_MADE' and player1_id = p.id then 2
								when event_msg_type = 'FREE_THROW' and player1_id = p.id and score is not null then 1
								else null end) as points,
					sum(case 	when event_msg_type = 'FIELD_GOAL_MADE' and player2_id = p.id then 1 
								when event_msg_type = 'FREE_THROW' and player2_id = p.id and score is not null then 1
								else null end) as assists,
					sum(case 	when event_msg_type = 'REBOUND' then 1 
								else null end) as rbds,
					0 as streak
				from (
						select 
							*
						from play_records pr 
						join games g on pr.game_id = g.id
						where g.season_id = '22018'
						and pr.event_msg_type in ('FIELD_GOAL_MADE', 'FREE_THROW', 'REBOUND')
					) as r
				join players p on p.id in (r.player1_id, r.player2_id)
				group by r.game_id, p.id
				order by p.id, r.game_id asc
				)scr
				-- where scr.id = 203901 -- debug
			) scr
			-- where scr.id = 201566 -- debug
		) grps
-- where grps.id = 201566 -- debug
where grps.double_triple = true
group by grps.id, grps.blocks
)
select 
	s.id,
	max(s.streaks) as longest_streak
from streaks s
group by s.id
having max(s.streaks) > 1
order by max(s.streaks) desc