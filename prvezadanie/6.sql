SELECT 
	*
FROM 
	play_records r
join players p
on p.id = r.player1_id 
-- where p.first_name = 'Lebron' and p.last_name = 'James'
limit 100