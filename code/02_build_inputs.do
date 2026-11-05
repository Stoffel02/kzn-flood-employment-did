*===============================================================================
* 02_build_inputs.do - rebuild the input datasets the original script expects
* Part of the pipeline run by master.do (needs the globals set there).
* PIPELINE: these steps were originally done interactively. Each block below was
* checked with -cf- and reproduces the author's original .dta file exactly.
*===============================================================================
clear

*--- (a) Monthly FTE per local municipality -----------------------------------
import delimited "$raw/Local_Municipal_Data/Municipal_FTE_Monthly.csv", case(preserve) clear
* Lines below are the (commented-out) cleaning steps from the original script
drop if CAT_B == "Missing Location Data"
drop if CAT_B == "Unknown Location - Head Office Anomaly"
gen month_date = date(month, "YMD")
gen yyyymm = year(month_date)*100 + month(month_date)
drop month_date
rename (yyyymm) (y_m_date)
save "$work/Local_Municipal_Data_FTE_Monthly.dta", replace

*--- (b) Share of importing establishments per municipality-year --------------
import delimited "$raw/Local_Municipal_Data/Municipal_Establishments_Import.csv", case(preserve) clear
* FLAG (data): 7 suppressed "<10" cells become missing here (the industry build imputes 5 instead)
destring Establishments, replace force float
drop if CAT_B == "Missing Location Data"
drop if CAT_B == "Unknown Location - Head Office Anomaly"

* --- original Import_Establisments.do (unchanged) ---
* First, get the total establishments per municipality-year
bysort CAT_B TaxYear: egen total_est = total(Establishments)

* Then, get total importing establishments per municipality-year
bysort CAT_B TaxYear (Import): egen import_est = total(cond(Import==1, Establishments, 0))

* Finally, compute proportion of importing establishments
gen prop_import = import_est / total_est

keep if Import == 1
drop Import

rename (TaxYear) (year)
* --- end of original ---
drop Establishments
sort CAT_B year
save "$work/Modified_muni_import_establishments.dta", replace

*--- (c) Yearly median income per municipality --------------------------------
import delimited "$raw/Local_Municipal_Data/Municipal_MedianIncome.csv", case(preserve) clear
rename (TaxYear) (year)
drop FTE
save "$work/yearly_muni_median_income.dta", replace

*--- (d) Municipal boundaries (attributes + polygons for spmatrix/grmap) -------
* spshape2dta writes into the current directory, which master.do sets to $work
spshape2dta "$raw/Local_Municipal_Shapefiles/MDB_Local_Municipal_Boundary_2018.shp", replace saving(MDB_Local_Municipal_Boundary_2018)
