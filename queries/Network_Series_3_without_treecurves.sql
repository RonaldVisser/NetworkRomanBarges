SELECT 
  series_with_series."Series_A", 
  series_with_series."Series_B",
  series_with_series."Radius_A",
  series_with_series."Radius_B",
  series_with_series.overlap,
  series_with_series.r,
  series_with_series.r_wuchs,
  series_with_series.t,
  series_with_series.t_wuchs,
  series_with_series."SGC",
  series_with_series."SSGC",
  series_with_series.p,
  (r_wuchs + (t_wuchs/10) + "SGC") as sum_sims
FROM 
  public.series_with_series,
  (SELECT monsters.monstercode FROM  public.monsters WHERE soort ='QUSP') as A,
  (SELECT monsters.monstercode FROM  public.monsters WHERE soort ='QUSP') as B
where 
r_wuchs > 0.5 and overlap >= 50
and p <= 0.0001
and series_with_series."Series_A" <> series_with_series."Series_B"
and series_with_series."Series_A" not like '%QT%'
and series_with_series."Series_B" not like '%QT%'
and A.monstercode=series_with_series."Series_A"
and B.monstercode=series_with_series."Series_B"
order by "Series_A","Series_B"