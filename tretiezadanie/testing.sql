-- TESTS
--CASTING spell when not in battle
call cast_spell(1,1,1);
--QUEUE LOOTING ITEM when not in battle
call queue_loot_item(1,1);
--ENTERING battle with unknown character or battlefield
call enter_battle(20,1);
call enter_battle(1,30);
call enter_battle(20,30);
--ENTERING battle multiple times
call enter_battle(1,1);
call enter_battle(1,1);
--ENTERING multiple battles
call enter_battle(2,1);
call enter_battle(2,2);

select*from characters;
select*from character_locations order by character_id, change_time desc;
--RESET FOR repleneshing 
call reset_round(1);
select*from characters;

--CASTING spell with not known variables
call cast_spell(10,1,1);
call cast_spell(1,10,1);
call cast_spell(1,1,10);
--CASTING spell onto character not in this battle
call cast_spell(1,1,4);

--RESETING unknown battle
call reset_round(10);

--TESTING looting in battle
--UNKNOWN variables
call queue_loot_item(1,10);
call queue_loot_item(10,1);
--gathering all items of the same type
select*from battle_inventory;
call queue_loot_item(1,2);
call queue_loot_item(1,2);
call queue_loot_item(1,2);
call queue_loot_item(1,2); -- multiple times as it is chance based
select*from battle_log;
call reset_round(1);
select*from battle_inventory;

--TESTING death in battle
call cast_spell(1,1,2);
call cast_spell(1,1,2);
call cast_spell(1,1,2);
call cast_spell(1,1,2);
call cast_spell(1,1,2);
call cast_spell(1,1,2);
call cast_spell(1,1,2);
select*from battle_log;
call reset_round(1);
select*from battle_log;
select*from characters;
select*from character_locations order by character_id, change_time desc;







--
call enter_combat(1,1);
call enter_combat(2,1);
call enter_combat(3,1);
call reset_round(1); -- round 0
call cast_spell(1,1,2);
call cast_spell(1,1,3);
call cast_spell(1,2,2);
call cast_spell(2,3,1);
call cast_spell(2,4,3);
call cast_spell(2,4,3);
call cast_spell(3,5,1);
call cast_spell(3,6,1);
call cast_spell(3,4,1);
call cast_spell(3,6,2);
call reset_round(1);
call queue_loot_item(3,1);
call queue_loot_item(3,1);
call cast_spell(3,4,1);
call cast_spell(3,6,2);
call cast_spell(1,1,2);
call cast_spell(1,1,3);
call cast_spell(1,2,2);
call cast_spell(2,3,1);
call cast_spell(2,4,3);
call cast_spell(2,4,3);
call reset_round(3);
select*from battle_log;
select*from turn_log;
select*from characters;
select*from character_inventory where owner_id = 2;
select*from battle_inventory;
select*from character_locations order by character_id, change_time desc;