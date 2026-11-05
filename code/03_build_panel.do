*===============================================================================
* 03_build_panel.do - merge inputs into the municipality-month panel
* Part of the pipeline run by master.do (needs the globals set there).
* Output: $work/panel_full.dta  (original script lines 3-81, 89-105, 114-151)
*===============================================================================
clear

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

* PIPELINE: deprecated label lines (orig. 82-87) moved to exploratory only
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

* PIPELINE: matched-sample merge and geodist (orig. 106-113) moved to 05_did_sample.do / exploratory



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


* PIPELINE: save panel for the next steps
save "$work/panel_full.dta", replace
