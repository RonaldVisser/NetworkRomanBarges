select monstercode, bouwfase_structuur_, monster_jaarringpat, stamcode, lengte, breedte_diameter
from monsters
where locatieid in ('ZwammerdamS1', 'ZwammerdamS2', 'ZwammerdamS4', 'ZwammerdamS6', 'WoerdenS7')
and monstercode <> 'ZWAMMK4'