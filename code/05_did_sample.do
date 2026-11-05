*===============================================================================
* 05_did_sample.do - restrict to matched sample and build DiD variables
* Part of the pipeline run by master.do (needs the globals set there).
* Output: $work/analysis_panel.dta  (original script lines 107-110, 192-206, 210-226, 245-248, 371-375, 429-436)
*===============================================================================
clear

use "$work/panel_full.dta", clear
* PIPELINE: matched_municipalities.dta is created by 04_psm_controls.do
merge m:1 panel_ID using "$work/matched_municipalities.dta"
drop _merge
rename new_treated treated
xtset panel_ID mdate
**# Bookmark #7
//DiD set up
xtset panel_ID mdate

*Creat a dummy variable to indicate the time when the treatment started. All months before 2017m5 will have a value of 0, and the months from 2017m5 until 6 months later will be 1.
gen time = 0 
replace time = 1 if mdate >= tm(2017m5) 

gen time_1m = 0
replace time_1m = 1 if mdate >= tm(2017m5) & mdate <= tm(2017m6)

*gen 3 month time
gen time_3m = 0
replace time_3m = 1 if mdate >= tm(2017m5) & mdate<=tm(2017m8)
*create a dummy variable to identify the group exposed to the treatment.
* PIPELINE: treated comes from the matched list above, so the PSM-pass definition (orig. 207-209) is skipped

gen time_6m = 0
replace time_6m = 1 if mdate >= tm(2017m5) & mdate<=tm(2017m11)

gen time_12m = 0
replace time_12m = 1 if mdate >= tm(2017m5) & mdate<=tm(2018m5)

*create an interaction between time and treated. Call it did
gen did = time*treated  

gen did_1m = time_1m*treated

gen did_3m = time_3m*treated 

gen did_6m = time_6m*treated

gen did_12m = time_12m*treated
//Trimming dataset to only include up to 2019 due to Covid and drop 2013 because data is incomplete
drop if year>2019 
//Drop metro observations from sample
drop if is_metro == 1
*Trim dataset to only include treated group and controls
 
keep if treated == 1  | treated == 0
drop if mdate<=tm(2013m12)
drop if year>2019
*Gen log transform of all the sectoral allocations
gen l_FTE_tradable_prim = ln(FTE_tradable_primary)
gen l_FTE_tradable_manu = ln(FTE_tradable_manu)
gen l_FTE_tradable_serv = ln(FTE_tradable_services)
gen l_FTE_nontradable_gov = ln(FTE_nontradable_gov)
gen l_FTE_nontradable_services = ln(FTE_nontradable_services)
gen l_FTE_total_tradable = ln(FTE_total_tradable)
gen l_FTE_total_nontradable = ln(FTE_total_nontradable)

* PIPELINE: save analysis sample
save "$work/analysis_panel.dta", replace
