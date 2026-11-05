*===============================================================================
* ORIGINAL WORKING SCRIPT - kept for transparency, NOT part of the pipeline.
* It does not run top to bottom (see the '* FLAG' comments). The reproducible
* pipeline is master.do -> code/01..09, which copies the final blocks verbatim.
*===============================================================================
//Stephan Monthly FTE by local Muni
//WARNING! DO NOT RUN ENTIRE THING AT ONCE, SOME CODE LEFT IN TO SHOW HOW SOME MERGED IN DATA WAS CREATED
//Use FTE monthly data as base
use "$work/Local_Municipal_Data_FTE_Monthly.dta"

//Clean data from error observations
* FLAG (provenance): the commented-out lines below were run once on Municipal_FTE_Monthly.csv to create Local_Municipal_Data_FTE_Monthly.dta.
//drop if CAT_B == "Missing Location Data"
//drop if CAT_B == "Unknown Location - Head Office Anomaly"

//Generate new year_month variable
//gen month_date = date(month, "YMD")
//gen yyyymm = year(month_date)*100 + month(month_date)
//drop month_date
//rename (yyyymm) (y_m_date)

//Merge with boundary data
merge m:1 CAT_B using "$work/MDB_Local_Municipal_Boundary_2018.dta"

drop _merge
drop DATE

//Create Unique panel ID's

encode CAT_B, gen(panel_ID)
xtset panel_ID y_m_date

//Winsorize by municipality to maintain balanced panel and because there are weird data errors
//bysort MUNICNAME: replace FTE = cond(FTE < r(p5), r(p5), FTE) if FTE < r(p5)
//bysort MUNICNAME: replace FTE = cond(FTE > r(p95), r(p95), FTE) if FTE > r(p95)
//Create modified FTE variables: gen log_fte

gen log_FTE = ln(FTE)
// generate difference in logs to calculate month-month and year-year growth for fte workers
xtset panel_ID y_m_date
gen d_log_FTE = D.log_FTE

//Create new somewhat temporary ym date and xtset to make yoy_log_FTE possible
gen mdate = ym(floor(y_m_date/100), mod(y_m_date,100))
format mdate %tm
xtset panel_ID mdate

gen yoy_log_FTE = log_FTE - L12.log_FTE

//Gen new yoy FTE growth as percentage
gen yoy_growth_FTE = 100 * (exp(yoy_log_FTE) - 1)

//Restate old dating in xtset
xtset panel_ID y_m_date

//Create year variable for each monthly observation to enable merging with import firm data
gen year = floor(y_m_date/100)

//merge yearly import data with monthly ds; NOTE that import data only until 2022
merge m:1 CAT_B year using "$work/Modified_muni_import_establishments.dta"
drop _merge

rename (total_est) (total_firms)
rename (import_est) (import_firms)


//Merge in industry montly FTE data
merge 1:1 CAT_B month using "$work/New_monthly_industry.dta"
drop _merge

*Merge in yearly  Median income data
merge m:1 CAT_B year using "$work/yearly_muni_median_income.dta"
drop _merge

//Clean data from error observations
drop if CAT_B == "Missing Location Data"
drop if CAT_B == "Unknown Location - Head Office Anomaly"


*Sectoral allocations
gen FTE_tradable_primary_share = FTE_tradable_primary/FTE
gen FTE_tradable_manu_share = FTE_tradable_manu/FTE
gen FTE_tradable_services_share = FTE_tradable_services/FTE
gen FTE_nontradable_gov_share = FTE_nontradable_gov/FTE
gen FTE_nontradable_services_share = FTE_nontradable_services/FTE

//deprecated
. label variable FTE_agri_forestry_fishing "FTE_Agri_Fish_Forest"

. label variable FTE_manufacturing "FTE_Manufacturing"

. label variable FTE_tourism "FTE_Tourism"

* Convert string PROVINCE to numeric with labels
encode PROVINCE, gen(province_id)
encode DISTRICT_N, gen(district_id)

spmatrix create contiguity W if y_m_date == 201510, replace

*Flag metros
gen byte is_metro = CATEGORY =="A"
*For each municipality check if any neighbour is a metro
spgenerate metro_neigh_count = W*is_metro if y_m_date==201510
sort _ID
by _ID: egen metro_neigh_count_all = max(metro_neigh_count)
*1 if neigbour a metro
gen byte neighb_metro = metro_neigh_count_all > 0

*Get the distance of all municipalities from a metro

* FLAG (reproducibility): matched_municipalities.dta (panel_ID new_treated) is created further down by the PSM block, so this merge only works on a second pass.
merge m:1 panel_ID using "$work/matched_municipalities.dta"
drop _merge
rename new_treated treated
xtset panel_ID mdate

* FLAG (reproducibility): flood_CY/flood_CX only exist after the (deprecated) flood merge below; this line errors on the current panel.
geodist _CY _CX flood_CY flood_CX, gen(dist_km)



* First flag units that exist in 2013
bysort panel_ID: gen had2013 = (mdate == tm(2013m12))
bysort panel_ID: egen ever2013 = max(had2013)



gen affected = 0

//These are the district municipalities affected by the flood in 2017, and only including municipalities that existed in the base year 2013.
* FLAG (reproducibility): treated districts are selected by encode-generated codes, which depend on the alphabetical order of DISTRICT_N. Consider selecting by district name instead.
replace affected = 1 if inlist(district_id, 42, 52, 24, 39) 
//replace affected = 1 if (dist_km < flood_radius) & province_id==4
*Data check: some sector FTE totals exceed total municipal FTE
// Flag if ANY sector is greater than total FTE
gen invalid = 0
replace invalid = 1 if FTE_tradable_primary > FTE
replace invalid = 1 if FTE_tradable_manu > FTE
replace invalid = 1 if FTE_tradable_services > FTE
replace invalid = 1 if FTE_nontradable_gov > FTE
replace invalid = 1 if FTE_nontradable_services > FTE

// See how many you'll drop
count if invalid == 1
tab panel_ID if invalid == 1 & year<=2019 & inlist(district_id, 42, 52, 24, 39)
tab panel_ID if affected==1 & invalid==1

tab panel_ID if inlist(district_id, 42, 52, 24, 39)
// Drop invalid rows
drop if invalid == 1 
drop if year>2019
drop invalid
tab panel_ID if affected==1
*Drop 
list panel_ID FTE FTE_tradable_manu FTE_tradable_manu_share if FTE_tradable_manu/FTE >=1


///////////////////////////////////////////////////////////////////////////////////////////////////
//BEWARE: THESE PARTS JUST SHOW THE PREP FOR MAKING THE TEMPORARY FILE TO ENABLE ITS MERGING WITH THE MAIN FILE
//NOW DEPRECATED
///////////////////////////////////////////////////////////////////////////////////////////////////////

//Keep all muni-months, even if no flood that month; can have floods being more than one month
joinby y_m_date using "$work/SA_floods_expanded.dta", unmatched(master) _merge(_merge)

//Compute distance from muni centroid to flood centroid
geodist _CY _CX flood_CY flood_CX, gen(dist_km)

drop if y_m_date!= 201705

//Mark if municipality is inside flood radius; 1 if the muni centroid lies inside the flood radius that month and 0 if ouside or if no flood matched that muni_month
gen affected = (dist_km < flood_radius) if !missing(dist_km)
replace affected = 0 if missing(affected)

gen affected = 0
replace affected = 1 if (dist_km < flood_radius) & province_id==4
//Collapse back to one row per muni–month
//Since some muni-months may appear more than once (multiple floods in same month), reduce it:

collapse (max) affected (sum) Dead Displaced (max) Severity dist_km, by(_ID y_m_date)


* Save as a SEPARATE file
save "$work/muni_flood_panel.dta", replace
//cycle back to start te use the new dataset then merge in the above dataset 
/////////////////////////////////////////////////////////////////////////////////////////////
//CAN RESUME RUNNING EVERYTHING FROM HERE
//ADD FLOODING DATASET
//merge 1:1 _ID y_m_date using "$work/muni_flood_panel.dta"
//drop _merge

//bysort panel_ID: egen treated = max(affected) 
*Focusing on 2017 KZN flood
*not doing this anymore, controls are from all over SA
//keep if province_id == 4 

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

*Create event-time dummies
sort panel_ID mdate
gen event_time = .
replace event_time = mdate - tm(2017m5) if treated==1
gen post_1m  = event_time==1  & treated==1
gen post_2m  = event_time==2  & treated==1
gen post_3m  = event_time==3  & treated==1
gen post_4m  = event_time==4  & treated==1
gen post_5m  = event_time==5  & treated==1
gen post_6m  = event_time==6  & treated==1
gen post_12m = event_time==12 & treated==1
gen post_24m = event_time==24 & treated==1

//Regression with event time dummies to study dynamic path
xtdidregress (log_FTE post_1m post_2m post_3m post_4m post_5m post_6m) (did), group(panel_ID) time(mdate) vce(cluster panel_ID)


//Trimming dataset to only include up to 2019 due to Covid and drop 2013 because data is incomplete
drop if year>2019 
//Drop metro observations from sample
drop if is_metro == 1



*****************
//gen byte affected = inlist(panel_ID, 79, 97, 92, 62, 61, 63) & mdate == tm(2017m5)

//Trimming dataset to only include up to 2019


* Post: 1 from first flood onward for treated; 0 otherwise
//gen byte post_flood = (mdate >= tm(2017m5))

//gen byte treated = inlist(panel_ID, 79, 97, 92, 62, 61, 63)

*DiD variable
//gen DiD = post_flood*treated

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

* FLAG (reproducibility): estat trendplots needs xtdidregress results; it is not valid right after psmatch2.
estat trendplots,  xlabel(648 653 659 665 671 677 683 689 695 701 707 713 719, format(%tm) angle(45))

* Save matched municipalities list
keep panel_ID treated
save "$work/matched_municipalities.dta", replace


*---------------------------------------------------------------------------


list panel_ID _treated _weight _pscore if _treated==0 &  _weight!=. 
tab _treated

list panel_ID _treated _weight _pscore if _treated==1 & _weight==.
list panel_ID _treated _weight _pscore if _treated==1  

summarize _pscore if _treated==1
summarize _pscore if _treated==0  & _weight!=.

//Save the control group to merge back in later
* FLAG (reproducibility): these variables no longer exist after "keep panel_ID treated" above; legacy from an earlier version.
drop log_FTE FTE agri_FTE_share manufacturing_FTE_share tourism_FTE_share
keep if _treated==0 &  _weight!=.
gen byte control = treated==0

save "$work/Flood_control.dta", replace
*-----------------------------------------------------------------------------------------
*designate control group derived from psmatch2 process
//gen byte control = inlist(panel_ID, 12, 55, 57, 59, 59, 119, 135, 194, 196, 201)
* Merge in matched sample indicator
merge m:1 panel_ID using "$work/matched_municipalities.dta"
keep if _merge == 3
drop _merge




*Merge in flood control group
merge m:m panel_ID using "$work/Flood_control.dta"
drop _merge
drop _id _n1 _n2 _nn _pdif _pscore _treated _support _weight
replace control = 0 if control ==.


spmap is_metro using "$work/MDB_Local_Municipal_Boundary_2018_shp", id(_ID)

gen treat_control = .
replace treat_control = 2 if treated==1 
replace treat_control = 1 if control==1
*working spmap of treated municipalities; need to drop to only one year for these things to work or something
spmap treat_control using "$work/MDB_Local_Municipal_Boundary_2018_shp", id(_ID) clmethod(unique) fcolor("240 240 240" "204 0 0") ocolor("200 200 200" ..) osize(vthin ..) title("Treated municipalities, 2017m5")  plotregion(color(white)) graphregion(color(white)) 





*Trim dataset to only include treated group and controls
 
keep if treated == 1  | treated == 0
drop if mdate<=tm(2013m12)
drop if year>2019
**# Bookmark #6
*Descriptive statistics
*Total Employment in final Sample by Treated vs Control groups

collect clear

dtable FTE FTE_tradable_primary FTE_tradable_manu FTE_tradable_services FTE_nontradable_gov FTE_nontradable_services prop_import, by(treated)
collect export "$output/SumTab2.docx", as(docx) replace

*Portion of Employment per sector by Treatment stutus
dtable FTE_tradable_primary_share FTE_tradable_manu_share FTE_tradable_services_share FTE_nontradable_gov_share FTE_nontradable_services_share, by(treated)

collect export "$output/SumTab1.docx", as(docx) replace

* FLAG (reproducibility): no estimation results are active, so this and the outreg2 lines below fail.
est store mytable,
outreg2 [mytable] using "$output/TableSum1.doc", replace

outreg2 using "$output/TableSum1.doc", replace sum(log) keep ()

*Mean FTE: treated vs control, pre flood
preserve
keep if mdate < tm(2017m4)

* Collapse to muni-level pre-flood mean
collapse (mean) FTE, by(panel_ID treated)
* Table: mean FTE by treated status
table treated, c(mean FTE)

restore

collapse (mean) log_FTE FTE FTE_tradable_primary_share FTE_tradable_manu_share FTE_tradable_services_share FTE_nontradable_gov_share FTE_nontradable_services_share (first) treated y_m_date _ID _CX _CY Shape__Are Shape__Len year province_id district_id, by(panel_ID)


grmap FTE_agri_forestry_fishing , clnumber(6) clmethod(quantile) fcolor(erose ebg eltblue emidblue edkblue) ocolor(ebg) osize(thin) legenda(on) legend(position(7) col(1) ring(1)) t(688)

* FLAG: removed a `do` call to a Stata temp file (left over from running a selection in the Do-file Editor; it only existed on the author's machine)



grmap FTE , clnumber(5) clmethod(quantile) fcolor(erose ebg eltblue emidblue edkblue) ocolor(ebg) osize(thin) legenda(on) legend(position(7) col(1) ring(1)) t(688) 

bysort MUNICNAME: egen avg_total_firms = mean(total_firms)

grmap total_firms , clnumber(5) clmethod(quantile) fcolor(erose ebg eltblue emidblue edkblue) ocolor(ebg) osize(thin) legenda(on) legend(position(7) col(1) ring(1)) t(687) 
grmap avg_total_firms , clnumber(5) clmethod(quantile) fcolor(erose ebg eltblue emidblue edkblue) ocolor(ebg) osize(thin) legenda(on) legend(position(7) col(1) ring(1)) t(688) 


grmap did, clnumber(2) clmethod(quantile) fcolor(erose ebg eltblue emidblue edkblue) ocolor(ebg) osize(thin) legenda(on) legend(position(7) col(1) ring(1)) t(688) 

tsline


*Gen log transform of all the sectoral allocations
gen l_FTE_tradable_prim = ln(FTE_tradable_primary)
gen l_FTE_tradable_manu = ln(FTE_tradable_manu)
gen l_FTE_tradable_serv = ln(FTE_tradable_services)
gen l_FTE_nontradable_gov = ln(FTE_nontradable_gov)
gen l_FTE_nontradable_services = ln(FTE_nontradable_services)
gen l_FTE_total_tradable = ln(FTE_total_tradable)
gen l_FTE_total_nontradable = ln(FTE_total_nontradable)

est clear

* FLAG (reproducibility): event_time was already created above; this line errors.
gen event_time =mdate 
xtset
**# Bookmark #5

gen d_l_FTE_tradable_prim = D.l_FTE_tradable_prim





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

**# Sector regs #8

est clear

xtdidregress (log_FTE l1.log_FTE ) (did_6m) , group(panel_ID) time(mdate) vce(cluster panel_ID) 



xtdidregress (log_FTE ) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID) 
est store model1 
*Regression checking for differences of sectoral employment
xtdidregress (l_FTE_tradable_prim ) (did_12m) , group(panel_ID) time(mdate) vce(cluster panel_ID) 
est store model2
xtdidregress (l_FTE_tradable_manu) (did_12m) , group(panel_ID) time(mdate) vce(cluster panel_ID) 
est store model3 
xtdidregress (l_FTE_nontradable_gov) (did_12m) , group(panel_ID) time(mdate) vce(cluster panel_ID)
est store model4 
xtdidregress (l_FTE_nontradable_services) (did_12m) , group(panel_ID) time(mdate) vce(cluster panel_ID)
est store model5 
xtdidregress (l_FTE_tradable_serv) (did_12m) , group(panel_ID) time(mdate) vce(cluster panel_ID)
est store model6
xtdidregress (l_FTE_total_tradable) (did_12m) , group(panel_ID) time(mdate) vce(cluster panel_ID)
est store model7
xtdidregress (l_FTE_total_nontradable) (did_12m) , group(panel_ID) time(mdate) vce(cluster panel_ID)
est store model8 

esttab model2 model3 model4 model5 model6  using "$output/Sectors", rtf replace se label 

xtdidregress (log_FTE ) (did_12m) , group(panel_ID) time(mdate) vce(cluster panel_ID) 

* FLAG (syntax): bare variable list, not a command.
FTE_tradable_primary_share FTE_tradable_manu_share FTE_tradable_services_share FTE_nontradable_gov_share FTE_nontradable_services_share prop_import






*Use standard wildbootstrap for robustness
xtdidregress (log_FTE) (did) , group(panel_ID) time(mdate) wildbootstrap

xtdidregress (FTE_tradable_manu_share ) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID) 
xtdidregress (FTE_tradable_manu ) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID) 
eststo m1 

outreg2 using "$output/myreg.doc", replace

reghdfe log_FTE did, absorb(panel_ID  province_id#year ) vce(cluster panel_ID)

xtdidregress (log_FTE ) (did_3m) , group(panel_ID) time(mdate) vce(cluster panel_ID) 
xtdidregress (FTE_tradable_manu ) (did_3m) , group(panel_ID) time(mdate) vce(cluster panel_ID) 

* FLAG (reproducibility): agri_FTE_share, manufacturing_FTE_share, tourism_FTE_share and FTE_tourism come from an earlier version of the panel and are not created by this script; commands using them fail.
xtdidregress (log_FTE manufacturing_FTE_share  ) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID) aeq

xtdidregress (log_FTE l12.manufacturing_FTE_share l12.agri_FTE_share l12.MedianIncome l12.total_firms l12.prop_import ) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID)  

xtdidregress (manufacturing_FTE_share i.neighb_metro) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID)  aeq
xtdidregress (manufacturing_FTE_share ) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID) 

xtdidregress (agri_FTE_share ) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID) 





**# Bookmark #4
*Post estimation and Robustness checks
*------------
*Parallel Trends Assumption
estat trendplots
estat trendplots,  xlabel(648 653 659 665 671 677 683 689 695 701 707 713 719, format(%tm) angle(45))

estat ptrends

estat grangerplot
estat granger
* FLAG (results): interpretation of the parallel-trends test written as a comment.
*Do not have evidence to rejject tje null hypothesis of parllel trends 
*Both tests support the paralel trend assumtpion
dtable FTE , by(province_id) title(Table 1: Summary Statistics) 
**# Summary Stats

dtable FTE FTE_tradable_primary_share FTE_tradable_manu_share FTE_tradable_services_share FTE_nontradable_gov_share FTE_nontradable_services_share prop_import, by(treated) title(Table 1: Summary Statistics) export("$output/table 1 summary statistics.docx", as(docx) replace)

dtable FTE FTE_tradable_primary_share FTE_tradable_manu_share FTE_tradable_services_share FTE_nontradable_gov_share FTE_nontradable_services_share prop_import, by(province_id) title(Table 1: Summary Statistics) 

* FLAG (syntax): orphaned export() option - belongs to the dtable command above.
export("$output/table 1 summary statistics.docx", as(docx) replace)
twoway (connected log_FTE mdate if treated == 1, cmean)
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

xtset panel_ID mdate
xtdidregress (log_FTE l12.manufacturing_FTE_share l12.agri_FTE_share l12.MedianIncome l12.total_firms l12.prop_import ) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID)  



xtdidregress (log_FTE manufacturing_FTE_share agri_FTE_share MedianIncome total_firms prop_import ) (did3m) , group(panel_ID) time(mdate) vce(cluster panel_ID) aggregate(standard) 

*inspect
list panel_ID if treated==1 & neighb_metro==1 & y_m_date==201705
list panel_ID if treated==1 & neighb_metro==1 & y_m_date==201705, nolab
list panel_ID if treated==1 & y_m_date==201705, nolab


*---------------------------------------------------------------------------------------------------
*Only Using 2014 variables for base characteristics
* Agriculture FTE share
bysort panel_ID: egen baseline_agri_FTE_p = mean(agri_FTE_share) if year==2014
bysort panel_ID: replace baseline_agri_FTE_p = baseline_agri_FTE_p[1]

* Median income
bysort panel_ID: egen baseline_MedianIncome = mean(MedianIncome) if year == 2014
bysort panel_ID: replace baseline_MedianIncome = baseline_MedianIncome[1]

* Manufacturing FTE share
bysort panel_ID: egen baseline_manufacturing_FTE_p = mean(manufacturing_FTE_share) if year == 2014
bysort panel_ID: replace baseline_manufacturing_FTE_p = baseline_manufacturing_FTE_p[1]

* Tourism FTE share
bysort panel_ID: egen baseline_tourism_FTE_p = mean(tourism_FTE_share) if year == 2014
bysort panel_ID: replace baseline_tourism_FTE_p = baseline_tourism_FTE_p[1]



//Regression with event time dummies to study dynamic path
xtdidregress (log_FTE post_1m post_2m post_3m post_4m post_5m post_6m post_12m post_24m l12.manufacturing_FTE_share) (did), group(panel_ID) time(mdate) vce(cluster panel_ID) aeq


*pretty basic one 
*Trying to account for the feb dips due to "no-one working" seasonality
* 1. Get month-of-year (1=Jan, 2=Feb, ...)
gen monthnum = month(dofm(mdate))
* 2. Indicator for February
gen byte is_feb = (monthnum == 2)

*----------------------------------------------------
*Re-estimate the event study manually with reghdfe instead of xtdidregress:
replace event_time = . if treated == 0
sum event_time
gen event_time_shift = event_time - r(min)


reghdfe log_FTE i.event_time_shift , absorb(panel_ID mdate) vce(cluster panel_ID)


xtreg log_FTE did agri_FTE_share manufacturing_FTE_share tourism_FTE_share i.mdate, fe vce(cluster _ID)





xtdidregress (log_FTE post_1m post_2m post_3m post_4m post_5m post_6m post_12m baseline_MedianIncome baseline_agri_FTE_p baseline_manufacturing_FTE_p baseline_tourism_FTE_p ) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID) aggregate(standard) aeq

* FLAG (results): interpretation of the parallel-trends test written as a comment.
*I do not reject parallel trends
estat ptrends

estat trendplots 
*Effects over time, leads and lags woth 95% CI's
estat grangerplot

* FLAG (results): interpretation of the pre-trend test written as a comment.
*not concerned by pretrends
estat granger

xtset
xtdidregress (log_FTE  l12.manufacturing_FTE_share) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID) aggregate(standard)

xtdidregress (log_FTE manufacturing_FTE_share agri_FTE_share MedianIncome total_firms prop_import ) (did) , group(panel_ID) time(mdate) vce(cluster panel_ID) aggregate(standard) 

*Granger plot with verbose output
estat grangerplot, nodraw verbose
 
 
*with dlog
xtdidregress (d_log_FTE  manufacturing_FTE_share  ) (affected) if inrange(mdate, tm(2016m5), tm(2018m5)), group(panel_ID) time(mdate) vce(cluster panel_ID) aggregate(standard) aeq


// if inrange(mdate, tm(2016m5), tm(2018m5))

xtdidregress ( FTE_tourism ) (affected), group(panel_ID) time(mdate) vce(cluster panel_ID)

xtdidregress (log_FTE l12.agri_FTE_share l12.manufacturing_FTE_share l12.tourism_FTE_share  ) (affected), group(panel_ID) time(mdate) vce(cluster panel_ID) aeq
//Flood dummy

*compare treated vs control group
bysort treated: summarize log_FTE FTE agri_FTE_share manufacturing_FTE_share tourism_FTE_share 

estat trendplots 

* FLAG (results): interpretation of the pre-trend test written as a comment.
*not concerned by pretrends
estat granger

*some exploration and checks
 bysort affected: summarize total_firms 

//gen flood_dummy = affected == 1

//Replace missing flood variables with 0
foreach var in affected Dead Displaced Severity {
    replace `var' = 0 if missing(`var')
}

//Create flood dummy at the monthly level
//bysort mdate: egen flood_month = max(flood_dummy)

gen flood_w = affected*Severity



//Trimming outliers
sum FTE, detail
//Winsorize by municipality to maintain balanced panel
bysort MUNICNAME: replace FTE = cond(FTE < r(p5), r(p5), FTE) if FTE < r(p5)
bysort MUNICNAME: replace FTE = cond(FTE > r(p95), r(p95), FTE) if FTE > r(p95)



* Ever treated: municipality that is affected in ANY month
bysort _ID: egen ever_treated = max(affected)
gen treated = ever_treated

* First flood month per treated municipality
bysort _ID (mdate): egen first_flood_m = min(mdate) if affected == 1
bysort _ID: egen first_flood = min(first_flood_m)

* Event time (months relative to first flood)
gen event_time = mdate - first_flood

* Post: 1 from first flood onward for treated; 0 otherwise
gen post = (mdate >= first_flood) if treated == 1
replace post = 0 if treated == 0

* rename for clarity
gen post_flood = post

*Create the diff-in-diff indicator
gen did = post_flood * treated

* Quick check
tab treated
tab post_flood if treated == 1

*==========================
* EVENT-STUDY (OPTIONAL)
*==========================
* Cap event_time to [-12, 12]
gen et = event_time
replace et = -12 if et < -12 & !missing(et)
replace et =  12 if et > 12 & !missing(et)

gen et_shift = et + 12 if !missing(et)

eststo est2: xtreg log_FTE i.et_shift ///
    agri_FTE_share manufacturing_FTE_share prop_import ///
    i.year, fe vce(cluster _ID)

xtreg log_FTE i.post_flood##i.treated agri_FTE_share manufacturing_FTE_share prop_import i.year, fe vce(cluster _ID)
*---------------------
*Baseline
*---------------------
eststo est1:xtdidregress (log_FTE) (did), group(_ID) time(mdate) aeq

*------------------------
* Main DiD with controls
*------------------------
xtset _ID mdate
*When I add prop of import it does funky things
eststo est2:xtdidregress (log_FTE l12.agri_FTE_share l12.manufacturing_FTE_share l12.tourism_FTE_share l12.prop_import ) (did), group(_ID) time(mdate) vce(cluster _ID) aeq

eststo est4:xtdidregress (log_FTE agri_FTE_share manufacturing_FTE_share tourism_FTE_share) (did), group(_ID) time(mdate) vce(cluster _ID) aeq 

eststo est3: xtreg log_FTE i.did agri_FTE_share manufacturing_FTE_share tourism_FTE_share  i.mdate, fe vce(cluster _ID)


* FLAG (syntax): incomplete command (no file name after using).
esttab est3 est4 using 

esttab est1 est4 using "$output/table_did_results.rtf",se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) keep(did agri_FTE_share manufacturing_FTE_share tourism_FTE_share prop_import) label replace

*Postestimation and robustness
* FLAG (syntax): incomplete command (no treatment specified).
xtdidregress (log_FTE) 

*----------------------

eststo est1: xtreg log_FTE i.treated#i.post_flood agri_FTE_share manufacturing_FTE_share tourism_FTE_share i.mdate, fe vce(cluster _ID)

//Adds Dead
eststo est2:xtreg log_FTE i.affected#i.post_flood agri_FTE_share manufacturing_FTE_share prop_import Dead i.year, fe vce(cluster _ID)


outreg2 using "$output/new_baseline_results.doc", replace	

* Create binary for severe floods (with casualties)
gen severe = (Dead > 0) if !missing(Dead)

*Interact severity with post; helps distinguish effect of non severe floods from severe floods with death being a good indicator of severity
eststo est3: xtreg log_FTE i.severe#i.post_flood agri_FTE_share manufacturing_FTE_share prop_import i.year, fe vce(cluster _ID)

eststo est3: xtreg log_FTE i.severe#i.post_flood agri_FTE_share manufacturing_FTE_share prop_import i.year, fe vce(cluster _ID)

eststo est4: xtreg log_FTE i.severe#i.post_flood agri_FTE_share manufacturing_FTE_share prop_import i.year c.year#i.province, fe vce(cluster _ID)

eststo est5:xtreg log_FTE i.affected#i.post_flood agri_FTE_share manufacturing_FTE_share prop_import Dead  c.mdate#i.province, fe vce(cluster _ID)

esttab est1 est2 est3

//////////////////////////////////////////



* FLAG (reproducibility): first_flood_date and month_since are never created in this script (legacy flood-panel version); the code below fails.
//Create a simple treatment variable, it becomes 1 and stays on after a municipality's first flood.
gen affected_post = (y_m_date>=first_flood_date) & (first_flood_date!= .)

//make data strongly balanced
//spbalance, balance

//Maybe add other weighting matrixes for other types of analysis
//Create spatial weighting matrix, use contiguity
spmatrix create contiguity W if y_m_date == 201510, replace



* For untreated units, set month_since to 0 to avoid empty interactions
replace month_since = 0 if affected == 0 & missing(month_since)

// NEW: Create category that includes non-flooded municipalities as baseline
gen month_since_group = month_since
replace month_since_group = 0 if missing(month_since)  // Non-flooded areas = reference
//////
//Checking for proper panel construction
//xtdes              // Check panel balance
//misstable summarize
//tab affected       // How many observations have floods?
//tab year           // Coverage of 2014-2024?

// 1. Create reference category dummy for month prior to flood event
gen ref_period = (month_since == -1)

// 2. Create dummies for all leads (months before flood) and lags (months after flood)
forvalues t=-12/-2 {
    gen lead_m`t' = (month_since == `t')
}
forvalues t=0/24 {
    gen lag_p`t' = (month_since == `t')
}


//Workaround to enable grmap without collapsing the data
//generating the average FTE of each municipality, district and province 
bysort MUNICNAME: egen avg_FTE_muni = mean(FTE)
bysort DISTRICT_N: egen avg_FTE_district = mean(FTE)
bysort PROVINCE: egen avg_FTE_province = mean(FTE)

//Do the same for average yoy FTE growth
bysort MUNICNAME: egen avg_yoy_FTE_growth_muni = mean(yoy_growth_FTE)
bysort DISTRICT_N: egen avg_yoy_FTE_growth_district = mean(yoy_growth_FTE)
bysort PROVINCE: egen avg_yoy_FTE_growth_province = mean(yoy_growth_FTE)


// 1. How many municipalities EVER flooded?
bysort panel_ID: egen ever_flooded = max(affected)
tab ever_flooded

//////////////
//Collapses
//////////////
preserve
collapse (sum) n_floods = affected, by(year)
list year n_floods
restore
///////////////////////////////////////////////////////////////////////////
//DO UP TO HERE FOR DATASET CREATION, AFTER THIS DESCRIPTIVE STATISTICS
///////////////////////////////////////////////////////////////////////////

/////////////////////// 
//REGRESSIONS//////////
///////////////////////
//First attempt at a weighted flood-effect variable; uses Severity from the flood dataset in the interim
spxtregress log_FTE prop_import agri_FTE_share manufacturing_FTE_share i.affected, fe dvarlag(W) 

//USING reghdfe for higher dimensional fixed effects
reghdfe log_FTE i.affected prop_import agri_FTE_share manufacturing_FTE_share, absorb(panel_ID province_id#y_m_date) vce(cluster panel_ID) 

//STANDARD OLS REGRESSION
reg FTE prop_import agri_FTE_share manufacturing_FTE_share flood_w

reg log_FTE prop_import agri_FTE_share manufacturing_FTE_share flood_w

//Standard panel regression with time fixed effects
xtreg log_FTE flood_w prop_import agri_FTE_share manufacturing_FTE_share, fe 

xtreg log_FTE flood_w prop_import agri_FTE_share manufacturing_FTE_share i.year, fe 
//WITH ROBUST ERRORS (?)
xtreg log_FTE flood_w prop_import agri_FTE_share manufacturing_FTE_share i.year, fe vce(cluster _ID)

//It seems that some municipalities dropped out, will investigate further for now will use: force option to ignore them
//Spatials Regressions
spxtregress log_FTE prop_import flood_w , fe dvarlag(W) errorlag(W)

//added i.year to account for fixed effects from business cycles
spxtregress log_FTE total_firms prop_import agri_FTE_share manufacturing_FTE_share Severity i.affected i.year , fe dvarlag(W) errorlag(W) 

spxtregress yoy_growth_FTE total_firms prop_import agri_FTE_share manufacturing_FTE_share i.affected Severity , fe dvarlag(W) errorlag(W) 

spxtregress d_log_FTE prop_import agri_FTE_share manufacturing_FTE_share i.affected, fe dvarlag(W) errorlag(W)
//grmap for one month date at a time

//AI assisted workflow based on Barrutiabengoa et al.(2025)
// STEP 1: Simple baseline (non-spatial, no time FE)
xtreg log_FTE i.affected total_firms prop_import agri_FTE_share manufacturing_FTE_share, fe vce(cluster panel_ID)
est store model1

// STEP 2: Add year controls
xtreg log_FTE i.affected total_firms prop_import agri_FTE_share manufacturing_FTE_share i.year, fe vce(cluster panel_ID)
est store model2

// STEP 3: Add spatial terms (if spillovers matter)
spxtregress log_FTE total_firms prop_import agri_FTE_share manufacturing_FTE_share i.affected, fe dvarlag(W) errorlag(W)
est store model3

// STEP 4: Spatial + year FE (if it converges cleanly)
spxtregress log_FTE total_firms prop_import agri_FTE_share manufacturing_FTE_share i.affected i.year, fe dvarlag(W)
est store model4

// STEP 5: Create results table
esttab model1 model2 model3 model4, wide label

//Event-time effects
// Estimate effect at each event-time:
xtreg log_FTE i.month_since total_firms prop_import agri_FTE_share manufacturing_FTE_share i.year, fe vce(cluster panel_ID)
est store model1

//REGRESSION WITH FULL SAMPLE
xtreg log_FTE i.month_since_group total_firms prop_import agri_FTE_share manufacturing_FTE_share i.year, fe vce(cluster panel_ID)
est store model2

//Are agri areas different
xtreg log_FTE i.month_since_group##c.agri_FTE_share total_firms prop_import manufacturing_FTE_share i.year, fe vce(cluster panel_ID)
est store model3


xtreg d_log_FTE i.month_since_group#c.agri_FTE_share total_firms prop_import manufacturing_FTE_share agri_FTE_share i.year, fe vce(cluster panel_ID)
est store model4

esttab model3 model4, label

esttab model1 model2 model3 , wide label


//New regression attempt
xtreg log_FTE i.affected#i.month_since agri_FTE_share manufacturing_FTE_share prop_import  i.year, fe cluster (_ID)
est store baseline1

xtreg log_FTE affectedaffected_post agri_FTE_share manufacturing_FTE_share prop_import  y_m_date, fe cluster (_ID)
est store baseline2

xtreg log_FTE i.months_since_flood agri_FTE_share manufacturing_FTE_share prop_import  i.year, fe cluster (_ID)


outreg2 using "$output/baseline_results.doc", replace
//Spatial FE model with a spatial lag of the dependent variable
spxtregress log_FTE affected agri_FTE_share manufacturing_FTE_share prop_import  i.year, fe dvarlag(W)


* Set month_since = 0 for controls (never treated)
replace month_since = 0 if affected == 0
xtset _ID mdate
xtreg log_FTE i.affected##i.month_since agri_FTE_share manufacturing_FTE_share prop_import i.year, fe cluster(panel_ID)
//////////////////////////////////////////////////
//Create Summary Statistics
/////////////////////////////////////////////////
*------------------
*New version Stats
*------------------
estpost tabstat FTE , statistics(mean sd min max sum) columns(statistic) by(province)  

tabstat FTE agri_FTE_share manufacturing_FTE_share tourism_FTE_share , statistics( mean sd min max sum) columns(statistic) by(ever_treated) long varwidth(25)

. dtable FTE agri_FTE_share manufacturing_FTE_share tourism_FTE_share prop_import, by(province_id) title(Table 1: Summary Statistics) 
* FLAG (syntax): orphaned export() option - belongs to the dtable command above.
export("$output/table 1 summary statistics.docx", as(docx) replace)

levelsof province_id, local(provs)

foreach p of local provs {
	* FLAG (syntax): two commands merged on one line; the loop below is the corrected version.
	di "Summary statistics for province `p'"dtable FTE agri_FTE_share manufacturing_FTE_share tourism_FTE_share prop_import if province_id == `p',continuous(, statistics(mean sd min max)) nformat(%9.3f)title("Summary statistics – Province `p'")export("$output/summ_province`p'.docx", as(docx) replace)
}

levelsof province_id, local(provs)
foreach p of local provs {
    dtable FTE agri_FTE_share manufacturing_FTE_share tourism_FTE_share prop_import if province_id == `p', continuous(, statistics(mean sd min max)) nformat(%9.3f) title("Summary statistics – Province `p'") export("$output/summ_province`p'.docx", as(docx) replace)
}


*simple new sum statistic
bysort province_id: sum FTE


*Retry sum stats
dtable FTE

dtable FTE 

dtable FTE FTE_agri_forestry_fishing FTE_manufacturing FTE_tourism i.affected, by(province_id) 
  //export(province_summary.docx) replace


//DESCRIPTIVE STATISTICS GROUPED BY PROVINCE
tabstat FTE yoy_growth_FTE, by(PROVINCE) statistics(mean sd min max ) column(statistics) longstub
 //Only FTE
tabstat FTE, by(PROVINCE ) statistics(mean sd min max ) column(statistics) longstub
tabstat log_FTE, by(PROVINCE ) statistics(mean sd min max ) column(statistics) longstub
tabstat d_log_FTE, by(PROVINCE ) statistics(mean sd min max ) column(statistics) longstub


* Get summary stats by province into a dataset
statsby mean=mean(FTE) sd=sd(FTE) min=min(FTE) max=max(FTE), by(PROVINCE): summarize FTE

* Export with outreg2 to Word
outreg2 using "$output/FTE_summary.doc", word replace


 //By DISTRICT
tabstat FTE yoy_growth_FTE, by(DISTRICT_N ) statistics(mean sd min max n) column(statistics) longstub
 
 //BY LOCAL MUNICIPALITY
tabstat FTE yoy_growth_FTE, by(MUNICNAME) statistics(mean sd min max n) column(statistics) longstub

//FTE Country
tabstat FTE yoy_growth_FTE, statistics(mean sd min max n) column(statistics) longstub

//Table on when floods happen in sample, how many affected, how many municipalities affected; its a bit wonky from me rather taking undercount than overcount of dead and displaced
collect clear
table mdate if affected==1,statistic(sum affected ) statistic(sum Dead ) statistic(max Displaced ) statistic(max Severity ) nformat(%12.0fc) nototal


xtsum FTE

summarize FTE log_FTE d_log_FTE yoy_growth_FTE prop_import agri_FTE_share manufacturing_FTE_share flood_dummy affected Severity Dead Displaced

bysort year flood_dummy: summarize FTE prop_import

xtset _ID y_m_date

//Workaround to enable grmap without collapsing the data
//generating the average FTE of each municipality, district and province 
bysort MUNICNAME: egen avg_FTE_muni = mean(FTE)
bysort DISTRICT_N: egen avg_FTE_district = mean(FTE)
bysort PROVINCE: egen avg_FTE_province = mean(FTE)

//Can now just use any point in time in grmap to get average of whole period
grmap FTE, clnumber(5) clmethod(quantile) fcolor(erose ebg eltblue emidblue edkblue) ocolor(ebg) osize(thin) legenda(on) legend(position(7) col(1) ring(1) title("Average FTE (2014-2019)")) t(201810)

grmap log_FTE, clnumber(5) clmethod(quantile) fcolor(erose ebg eltblue emidblue edkblue) ocolor(ebg) osize(thin) legenda(on) legend(position(7) col(1) ring(1) title("Average log_FTE (2013-2019)")) t(201810)


//Do the same for average yoy FTE growth
bysort MUNICNAME: egen avg_yoy_FTE_growth_muni = mean(yoy_growth_FTE)
bysort DISTRICT_N: egen avg_yoy_FTE_growth_district = mean(yoy_growth_FTE)
bysort PROVINCE: egen avg_yoy_FTE_growth_province = mean(yoy_growth_FTE)

//Avg yoy growth FTE heatmap
grmap avg_yoy_FTE_growth_muni, clnumber(5) clmethod(quantile) fcolor(erose ebg eltblue emidblue edkblue) ocolor(ebg) osize(thin) legenda(on) legend(position(7) col(1) ring(1) title("Average year-on-year growth of FTE (2013-2019)")) t(201810) 

preserve
collapse (sum) FTE, by(panel_ID year)
summarize FTE
restore



* check monthly FTE totals per muni
preserve
collapse (sum) FTE, by(panel_ID month)
summarize FTE
restore

preserve
collapse (sum) FTE, by(MUNICNAME month)
summarize FTE
tabstat FTE, statistics(mean sd min max p25 p50 p75) by(year)
restore

preserve
collapse (mean) FTE, by( CAT_B)

restore



grmap treated , t(201706)

grmap FTE, t(201811)
grmap FTE, t(202006)

grmap prop_import, t(201406)

grmap yoy_log_FTE, t(201906)

grmap yoy_growth_FTE, t(201906)

grmap p1_avg_FTE, t(202202)

xtsum FTE

egen p1_avg_FTE = mean(FTE), by(panel_ID)
