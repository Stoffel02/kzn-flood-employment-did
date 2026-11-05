*===============================================================================
* 05_did_sample.do - restrict to matched sample and build DiD variables
* Part of the pipeline run by master.do (needs the globals set there).
* Output: $work/analysis_panel.dta  (original script lines 107-110, 192-206, 210-226, 245-248, 371-375, 429-436)
*===============================================================================
clear

use "$work/panel_full.dta", clear
* PIPELINE: choose the control group with $controls (set in master.do)
*   "thesis" - the 24 municipalities used in the thesis (10 treated, 14 controls).
*              This list came from an earlier version of the matching step and is
*              what the final analysis dataset and results were built on.
*   "psm"    - the output of 04_psm_controls.do exactly as coded (10 treated, 10 controls).
if "$controls" == "psm" {
merge m:1 panel_ID using "$work/matched_municipalities.dta"
drop _merge
rename new_treated treated
}
else if "$controls" == "thesis" {
    preserve
    clear
    input str6 CAT_B byte new_treated
    "KZN212" 1
    "KZN216" 1
    "KZN241" 1
    "KZN244" 1
    "KZN281" 1
    "KZN282" 1
    "KZN284" 1
    "KZN292" 1
    "KZN293" 1
    "KZN294" 1
    "EC101"  0
    "EC108"  0
    "EC122"  0
    "EC124"  0
    "EC136"  0
    "EC155"  0
    "EC157"  0
    "KZN225" 0
    "KZN266" 0
    "KZN276" 0
    "KZN433" 0
    "WC015"  0
    "WC024"  0
    "WC026"  0
    end
    save "$work/matched_municipalities_thesis.dta", replace
    restore
    merge m:1 CAT_B using "$work/matched_municipalities_thesis.dta"
    drop _merge
    rename new_treated treated
}
else {
    di as error `"global controls must be "thesis" or "psm""'
    exit 198
}
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
