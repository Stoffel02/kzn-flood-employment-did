*===============================================================================
* 08_sector_did.do - DiD by tradable / non-tradable sector
* Part of the pipeline run by master.do (needs the globals set there).
* Output: Sectors.rtf  (original script lines 495-523)
*===============================================================================
clear

use "$work/analysis_panel.dta", clear
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
