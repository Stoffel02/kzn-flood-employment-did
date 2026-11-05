*===============================================================================
* 09_robustness.do - robustness checks
* Part of the pipeline run by master.do (needs the globals set there).
* Output: myreg.doc  (original script lines 533-545, 585-617)
*===============================================================================
clear

use "$work/analysis_panel.dta", clear
*Use standard wildbootstrap for robustness
xtdidregress (log_FTE) (did) , group(panel_ID) time(mdate) wildbootstrap

xtdidregress (FTE_tradable_manu_share ) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID) 
xtdidregress (FTE_tradable_manu ) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID) 
eststo m1 

outreg2 using "$output/myreg.doc", replace

reghdfe log_FTE did, absorb(panel_ID  province_id#year ) vce(cluster panel_ID)

xtdidregress (log_FTE ) (did_3m) , group(panel_ID) time(mdate) vce(cluster panel_ID) 
xtdidregress (FTE_tradable_manu ) (did_3m) , group(panel_ID) time(mdate) vce(cluster panel_ID) 
**# Bookmark #5
*Secondary Control Group of EC municipalities
gen sec_treated = .
replace sec_treated = .
replace sec_treated =1 if treated ==1
replace sec_treated = 0 if province_id==1

*create an interaction between time and treated. Call it did
gen sec_did = time*sec_treated  

gen sec_did_1m = time_1m*sec_treated

gen sec_did_3m = time_3m*sec_treated 

gen sec_did_6m = time_6m*sec_treated

gen sec_did_12m = time_12m*sec_treated

xtdidregress (log_FTE ) (sec_did_12m) , group(panel_ID) time(mdate) vce(cluster panel_ID)

*sec_did_12m
xtdidregress (log_FTE l12.prop_import l12.FTE_tradable_primary_share l12.FTE_tradable_manu_share l12.FTE_tradable_services_share l12.FTE_nontradable_gov_share l12.FTE_nontradable_services_share) (sec_did_12m), group(panel_ID) time(mdate) vce(cluster panel_ID)

*did_12m
xtdidregress (log_FTE l12.prop_import l12.FTE_tradable_primary_share l12.FTE_tradable_manu_share l12.FTE_tradable_services_share l12.FTE_nontradable_gov_share l12.FTE_nontradable_services_share) (did_12m), group(panel_ID) time(mdate) vce(cluster panel_ID)

*-------------------------------------------------------------------------------------------

xtdidregress (log_FTE MedianIncome) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID) 



xtdidregress (log_FTE ) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID) 
