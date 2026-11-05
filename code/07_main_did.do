*===============================================================================
* 07_main_did.do - main difference-in-differences results
* Part of the pipeline run by master.do (needs the globals set there).
* Output: DIDresults.rtf  (original script lines 438, 451-493, 561-574)
*===============================================================================
clear

use "$work/analysis_panel.dta", clear
est clear
**# Bookmark #9
*My actual final regresions
//collect clear

xtdidregress (log_FTE l12.prop_import l12.FTE_tradable_primary_share l12.FTE_tradable_manu_share l12.FTE_tradable_services_share l12.FTE_nontradable_gov_share l12.FTE_nontradable_services_share) (did_1m), group(panel_ID) time(mdate) vce(cluster panel_ID)
est store month1

xtdidregress (log_FTE l12.prop_import l12.FTE_tradable_primary_share l12.FTE_tradable_manu_share l12.FTE_tradable_services_share  l12.FTE_nontradable_gov_share l12.FTE_nontradable_services_share)   (did_3m), group(panel_ID) time(mdate) vce(cluster panel_ID)
est store month3

xtdidregress (log_FTE l12.prop_import l12.FTE_tradable_primary_share  l12.FTE_tradable_manu_share l12.FTE_tradable_services_share   l12.FTE_nontradable_gov_share l12.FTE_nontradable_services_share)      (did_6m), group(panel_ID) time(mdate) vce(cluster panel_ID)
est store month6

xtdidregress (log_FTE l12.prop_import l12.FTE_tradable_primary_share  l12.FTE_tradable_manu_share l12.FTE_tradable_services_share  l12.FTE_nontradable_gov_share l12.FTE_nontradable_services_share)   (did_12m), group(panel_ID) time(mdate) vce(cluster panel_ID)
est store month12


xtdidregress (log_FTE l12.prop_import l12.FTE_tradable_primary_share  l12.FTE_tradable_manu_share l12.FTE_tradable_services_share )   (did_6m), group(panel_ID) time(mdate) vce(cluster panel_ID) aeq

xtdidregress (log_FTE l12.FTE_agri_forestry_fishing l12.FTE_mining_quarrying l12.FTE_manufacturing l12.FTE_electricity_gas_water l12.FTE_waste l12.FTE_construction l12.FTE_retail_wholesale l12.FTE_transportation l12.FTE_accommodation_food l12.FTE_info_comms l12.FTE_financial l12.FTE_real_estate l12.FTE_prof_scientific_techn l12.FTE_admin_support l12.FTE_public_admin_defence l12.FTE_education l12.FTE_health_social_work l12.FTE_recreation l12.FTE_other_services) (did_12m), group(panel_ID) time(mdate) vce(cluster panel_ID)


esttab month1 month3 month6 month12 using "$output/DIDresults", rtf replace se label mtitles("1_month" "3month" "6month" "12month")

**# Retrying with GDD

reghdfe log_FTE l12.prop_import l12.FTE_tradable_primary_share l12.FTE_tradable_manu_share  l12.FTE_tradable_services_share l12.FTE_nontradable_gov_share l12.FTE_nontradable_services_share did_1m, absorb(panel_ID mdate panel_ID#c.mdate)vce(cluster panel_ID)
est store gdd_1m







*Normal OLS regression without sample regression for demonstration
*without controls
reghdfe log_FTE did , absorb(panel_ID mdate) vce(cluster panel_ID)

reghdfe log_FTE did FTE_tradable_primary_share FTE_tradable_manu_share FTE_tradable_services_share FTE_nontradable_gov_share FTE_nontradable_services_share prop_import , absorb(panel_ID mdate) vce(cluster panel_ID)

*Check whether sectoral composition predicts employment growth
reghdfe log_FTE FTE_tradable_primary_share FTE_tradable_manu_share FTE_tradable_services_share FTE_nontradable_gov_share FTE_nontradable_services_share prop_import , absorb(panel_ID mdate) vce(cluster panel_ID)
* PIPELINE: the original session does not record which model these tests were run after.
* estat trendplots/ptrends/granger need a treatment that stays on (did, not did_1m-did_12m)
* and no time-series operators (l12.) among the controls, so they are run on the simple
* DiD model below, copied from the original script.
xtdidregress (log_FTE ) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID) 
**# Bookmark #4
*Post estimation and Robustness checks
*------------
*Parallel Trends Assumption
estat trendplots
estat trendplots,  xlabel(648 653 659 665 671 677 683 689 695 701 707 713 719, format(%tm) angle(45))
graph export "$output/parallel_trends.png", replace width(1600)   // PIPELINE: save the figure

estat ptrends

estat grangerplot
estat granger
* FLAG (results): interpretation of the parallel-trends test written as a comment.
*Do not have evidence to rejject tje null hypothesis of parllel trends 
*Both tests support the paralel trend assumtpion
