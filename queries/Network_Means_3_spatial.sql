SELECT DISTINCT
  mean_with_mean."Mean_A", 
  mean_with_mean."Mean_B", 
  mean_with_mean."Radius_A", 
  mean_with_mean."Radius_B", 
  mean_with_mean.overlap, 
  mean_with_mean.r, 
  mean_with_mean.r_wuchs, 
  mean_with_mean.t, 
  mean_with_mean.t_wuchs, 
  mean_with_mean."SGC", 
  mean_with_mean."SSGC", 
  mean_with_mean.p, 
  mean_with_mean."p_GLK",
  (r_wuchs + (t_wuchs/10) + "SGC") as sum_sims,
  lines_from_groups.line_geom,
  lines_from_groups.lines_id 
FROM 
  public.mean_with_mean,
  (SELECT site_chrono_info."SiteChrono"
     FROM  public.site_chrono_info WHERE "Soort" ='QUSP') as A,
  (SELECT site_chrono_info."SiteChrono"
     FROM  public.site_chrono_info WHERE "Soort" ='QUSP') as B,
   lines_from_groups
WHERE
  r_wuchs >= 0.5
  and overlap >= 50 
  and p <= 0.0001
  and A."SiteChrono"=mean_with_mean."Mean_A"
  and B."SiteChrono"=mean_with_mean."Mean_B"
  and mean_with_mean."Mean_A" <> mean_with_mean."Mean_B"
  and mean_with_mean."Mean_A" NOT IN ('WOS7_Q1a', 'WOS7_Q1b', 'ZWS2_Q1a', 'ZWS2_Q1b', 'ZWS4_Q1x', 'ZWS6_Q1a', 'ZWS6_Q1b')
  and mean_with_mean."Mean_B" NOT IN ('WOS7_Q1a', 'WOS7_Q1b', 'ZWS2_Q1a', 'ZWS2_Q1b', 'ZWS4_Q1x', 'ZWS6_Q1a', 'ZWS6_Q1b')
  and mean_with_mean."Radius_A" NOT IN ('V','L')
  and mean_with_mean."Radius_B" NOT IN ('V','L')
  and mean_with_mean."Mean_A" != 'HOL_WEDE' -- duplicate from HOL_WEDW
  and mean_with_mean."Mean_B" != 'HOL_WEDE' -- duplicate from HOL_WEDW
  and mean_with_mean."Mean_A" = lines_from_groups."Mean_A"
  and mean_with_mean."Mean_B" = lines_from_groups."Mean_B"
ORDER BY "Mean_A", "Mean_B"
