*===============================================================================
* 04_psm_controls.do - propensity-score match control municipalities
* Part of the pipeline run by master.do (needs the globals set there).
* Output: $work/matched_municipalities.dta  (original script lines 192-226, 245-248, 266-312, 316-319)
*===============================================================================
clear

* FLAG (reproducibility): this is the matching step as it stands in the original script.
* Section 5.3 of the thesis describes the match that produced the control group actually
* used (10 treated, 14 controls): log(FTE) and the five sector shares as covariates, two
* nearest neighbours, and no exclusion of untreated KwaZulu-Natal municipalities. The code
* below instead uses FTE and municipal area, one neighbour without replacement, and drops
* panel_ID 62-103. Neither version reproduces the thesis list exactly, so 05_did_sample.do
* uses that list directly by default ($controls = "thesis").

use "$work/panel_full.dta", clear
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
* FLAG (reproducibility): if the matched-sample merge near the top was run, treated already exists and this errors. Define treated here for the PSM pass, or merge the matched list for the estimation pass - not both.
gen treated = 0
replace treated = 1 if affected ==1

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
xtsum FTE 
xtset panel_ID mdate

* Make a categorical variable for mapping

*--------------------------------
*Create propper control group
*--------------------------------
*Restrict the sample to 2013 because first pre-treatment full year of data, averaged to smooth out. (Note: consider 2014m3)
keep if mdate<=tm(2013m12)

*Beacuase KZN is a coastal province makes sense to restrict the control group to similar coastal provinces of Eastern Cape and Western Cape
keep if inlist(province_id, 1, 4, 9)
*restrict the sample to the municipalities that are continuous to metros and my treated municipalities, done because the labour market of metro's and areas surounfing them are very different to more rural markets (cite)
* FLAG (reproducibility): hard-coded panel_ID range; panel_ID comes from encode CAT_B, so the numbers depend on the alphabetical order of municipality codes.
drop if panel_ID>= 62 & panel_ID<=103 & treated == 0
//keep if neighb_metro == 1 | treated ==1
*Drop the actual metros
drop if is_metro == 1
//preserve
collapse (mean) log_FTE FTE FTE_tradable_primary_share FTE_tradable_manu_share FTE_tradable_services_share FTE_nontradable_gov_share FTE_nontradable_services_share (first) treated y_m_date _ID _CX _CY Shape__Are Shape__Len year province_id district_id, by(panel_ID)
* FLAG (results): sample size written as a comment.
*Is now a sample of 76 muni's in 3 provinces
//gen byte treated = inlist(panel_ID, 79, 97, 92, 62, 61, 63)
//restore
*Should this be done? (would exclude the Western Cape)
*Exclude WC
//drop if panel_ID >=190 & panel_ID<=213

*------------------------------------------------------------
*Use only 2014 information to find similar control municipalities using psmatch2; MedianIncome doesnt exist in 2013
* FLAG (reproducibility): 1-nearest-neighbour matching without replacement depends on the sort order of the data and no seed is set, so the matched set can change between runs.
psmatch2 treated Shape__Are FTE FTE_tradable_primary_share FTE_tradable_manu_share FTE_tradable_services_share FTE_nontradable_gov_share FTE_nontradable_services_share , logit neighbor(1) noreplacement

pstest FTE Shape__Are FTE_tradable_primary_share FTE_tradable_manu_share FTE_tradable_services_share FTE_nontradable_gov_share FTE_nontradable_services_share , both 

pstest FTE FTE_tradable_primary_share FTE_tradable_manu_share FTE_tradable_services_share FTE_nontradable_gov_share FTE_nontradable_services_share

psgraph, treated(_treated)

summarize FTE if _weight != .

summarize _pscore if _treated==1
summarize _pscore if _treated==0  & _weight!=.

* Keep only matched sample
keep if _weight != . 
* PIPELINE: estat trendplots (orig. 314-315) removed here - not valid after psmatch2

* Save matched municipalities list
keep panel_ID treated
* PIPELINE: the author's saved file names this variable new_treated (renamed by hand); 05 renames it back
rename treated new_treated
save "$work/matched_municipalities.dta", replace
