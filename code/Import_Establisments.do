* First, get the total establishments per municipality-year
bysort CAT_B TaxYear: egen total_est = total(Establishments)

* Then, get total importing establishments per municipality-year
bysort CAT_B TaxYear (Import): egen import_est = total(cond(Import==1, Establishments, 0))

* Finally, compute proportion of importing establishments
gen prop_import = import_est / total_est

keep if Import == 1
drop Import

rename (TaxYear) (year)