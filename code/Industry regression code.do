*Regression checking for differences of sectoral employment
xtdidregress (l_FTE_tradable_prim prop_import) (did_12m) , group(panel_ID) time(mdate) vce(cluster panel_ID) 
est store model2
xtdidregress (l_FTE_tradable_manu prop_import) (did_12m) , group(panel_ID) time(mdate) vce(cluster panel_ID) 
est store model3 
xtdidregress (l_FTE_nontradable_gov prop_import) (did_12m) , group(panel_ID) time(mdate) vce(cluster panel_ID)
est store model4 
xtdidregress (l_FTE_nontradable_services prop_import) (did_12m) , group(panel_ID) time(mdate) vce(cluster panel_ID) level(90)
est store model5 
xtdidregress (l_FTE_tradable_serv prop_import) (did_12m) , group(panel_ID) time(mdate) vce(cluster panel_ID)
est store model6
* FLAG (syntax): prop_import is listed twice.
xtdidregress (l_FTE_total_tradable prop_import prop_import) (did_12m) , group(panel_ID) time(mdate) vce(cluster panel_ID)
est store model7
xtdidregress (l_FTE_total_nontradable prop_import) (did_12m) , group(panel_ID) time(mdate) vce(cluster panel_ID)
est store model8 

esttab model2 model3 model4 model5 model6  using "$output/Sectors", rtf replace se label 


