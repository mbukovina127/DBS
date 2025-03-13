with team_names as (select
	tg.id,
	tg.nickname,
	concat(min(year_founded), '-7-1 00:00:00')::timestamp as founded,
	concat(case when max(year_active_till) = '2019' then '2999' else max(year_active_till) end
			, '-6-30 00:00:00'
	)::timestamp as active
from	(select h.team_id as id, 
		h.nickname, 
		h.year_founded, 
		h.year_active_till, 
		coalesce(lag(h.year_active_till + 1) over (partition by h.nickname order by h.year_founded), 0) as pervious 
	from team_history h
	order by h.team_id asc, h.year_founded asc 
	) 
	as tg
group by tg.id, tg.nickname
order by tg.id asc, min(year_founded) asc
), team_nick_games as (
	select games.id as gid, games.home_team_id, games.away_team_id, games.game_date, team_names.* from games
	join team_names 
	on team_names.id in (games.home_team_id, games.away_team_id)
	and games.game_date > team_names.founded
	and games.game_date < team_names.active
	order by games.id
)
select 
	t.id, t.nickname as team_name, 
	t.away_matches as number_away_matches,
	ROUND((t.away_matches * 100.0 / (t.away_matches + t.home_matches)), 2) as percentage_home_matches,
	t.home_matches as number_home_matches,
	ROUND((t.home_matches * 100.0 / (t.away_matches + t.home_matches)), 2) as percentage_home_matches,
	t.away_matches + t.home_matches as total_games
from (
	select 
		team_nick_games.id, team_nick_games.nickname,
		count(case when team_nick_games.home_team_id = team_nick_games.id then 1 else null end) as home_matches,
		count(case when team_nick_games.away_team_id = team_nick_games.id then 1 else null end) as away_matches
	from team_nick_games
	group by team_nick_games.id, team_nick_games.nickname
) t