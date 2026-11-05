use "$work/SA flood data.dta"

drop if began_ym!=201705

gen flood_r = sqrt(Area/c(pi))

merge m:1 CAT_B using "$work/MDB_Local_Municipal_Boundary_2018.dta"