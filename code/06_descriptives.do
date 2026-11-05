*===============================================================================
* 06_descriptives.do - summary statistics tables
* Part of the pipeline run by master.do (needs the globals set there).
* Outputs: SumTab1.docx, SumTab2.docx, table 1 summary statistics.docx  (original lines 376-388, 575-580, 584)
*===============================================================================
clear

use "$work/analysis_panel.dta", clear
**# Bookmark #6
*Descriptive statistics
*Total Employment in final Sample by Treated vs Control groups

collect clear

dtable FTE FTE_tradable_primary FTE_tradable_manu FTE_tradable_services FTE_nontradable_gov FTE_nontradable_services prop_import, by(treated)
collect export "$output/SumTab2.docx", as(docx) replace

*Portion of Employment per sector by Treatment stutus
dtable FTE_tradable_primary_share FTE_tradable_manu_share FTE_tradable_services_share FTE_nontradable_gov_share FTE_nontradable_services_share, by(treated)

collect export "$output/SumTab1.docx", as(docx) replace

* PIPELINE: from the original Descriptive statistics.do (it used an older version of this dataset)
*Mean FTE by treated vs control

preserve
keep if mdate<tm(2017m5)

collapse (mean) FTE, by(panel_ID treated)
table treated, stat(mean FTE) stat (sd FTE)

restore
dtable FTE , by(province_id) title(Table 1: Summary Statistics) 
**# Summary Stats

dtable FTE FTE_tradable_primary_share FTE_tradable_manu_share FTE_tradable_services_share FTE_nontradable_gov_share FTE_nontradable_services_share prop_import, by(treated) title(Table 1: Summary Statistics) export("$output/table 1 summary statistics.docx", as(docx) replace)
dtable FTE FTE_tradable_primary_share FTE_tradable_manu_share FTE_tradable_services_share FTE_nontradable_gov_share FTE_nontradable_services_share prop_import, by(province_id) title(Table 1: Summary Statistics) 
* PIPELINE: removed "twoway (connected log_FTE mdate if treated == 1, cmean)" - cmean is not a valid option; the line is kept in exploratory/original_working_script.do
