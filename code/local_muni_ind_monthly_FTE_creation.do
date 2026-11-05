//Local muni industry monthly FTE data

import delimited "$raw/Local_Municipal_Data/Municipal_FTE_Industry5d_Monthly.csv", case(preserve) numericcols(8) clear


//Drop transport observations that dont have anything to do with tourism industry

//Drop the unnecesary SIC7 codes
drop SIC7_2d SIC7_3d SIC7_4d SIC7_5d

// Convert FTE string to numeric + handle <10 suppression
destring FTE, replace ignore("<10""<10")

// SARS Spatial Tax Panel STANDARD IMPUTATION
* FLAG (data): suppressed "<10" cells are imputed as 5 here, whereas the establishment-import build sets "<10" cells to missing.
replace FTE = 5 if FTE==.

//ssc install labutil2, replace

* See how many rows per municipality per month
bysort CAT_B month: gen count = _N
tab count

//collapse data for each muni industry and month
collapse (sum) FTE, by(CAT_B SIC7_1d month)


label define SIC7_1d_description     1 "Agriculture" 2 "Mining" 3 "Manufacturing" 4 "Electricity" 5 "Waste" 6 "Construction" 7 "Retail/Wholesale" 8 "Transportation" 9 "Accommodation" 10 "Info/Comms" 11 "Financial" 12 "Real Estate" 13 "Professional" 14 "Admin Support" 15 "Public Admin" 16 "Education" 17 "Health" 18 "Arts/Recreation" 19 "Other Services"

label values SIC7_1d SIC7_1d_description

//Reshape dataset so that new variable for each indstry FTE
reshape wide FTE, i(CAT_B month) j(SIC7_1d)

rename FTE1 FTE_agri_forestry_fishing
rename FTE2 FTE_mining_quarrying
rename FTE3 FTE_manufacturing
rename FTE4 FTE_electricity_gas_water
rename FTE5 FTE_waste
rename FTE6 FTE_construction
rename FTE7 FTE_retail_wholesale
rename FTE8 FTE_transportation
rename FTE9 FTE_accommodation_food
rename FTE10 FTE_info_comms
rename FTE11 FTE_financial
rename FTE12 FTE_real_estate
rename FTE13 FTE_prof_scientific_techn
rename FTE14 FTE_admin_support
rename FTE15 FTE_public_admin_defence
rename FTE16 FTE_education
rename FTE17 FTE_health_social_work
rename FTE18 FTE_recreation
rename FTE19 FTE_other_services

drop FTE20 FTE21

// TRADABLE: PRIMARY
gen FTE_tradable_primary = FTE_agri_forestry_fishing + FTE_mining_quarrying

// TRADABLE: MANUFACTURING
gen FTE_tradable_manu = FTE_manufacturing

// TRADABLE: SERVICES
gen FTE_tradable_services = FTE_info_comms + FTE_financial + FTE_prof_scientific + FTE_admin_support 

// NON-TRADABLE: GOVERNMENT
gen FTE_nontradable_gov = FTE_public_admin_defence + FTE_education + FTE_health_social_work

// NON-TRADABLE: SERVICES
gen FTE_nontradable_services = FTE_construction + FTE_retail_wholesale + FTE_accommodation_food + FTE_real_estate + FTE_recreation + FTE_transportation

// TOTALS
gen FTE_total_tradable = FTE_tradable_primary + FTE_tradable_manu + FTE_tradable_services
gen FTE_total_nontradable = FTE_nontradable_gov + FTE_nontradable_services


save "$work/New_monthly_industry.dta", replace
