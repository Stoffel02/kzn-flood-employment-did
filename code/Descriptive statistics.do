*Mean FTE by treated vs control
use "$work/final treated vs control complete.dta"

preserve
keep if mdate<tm(2017m5)

collapse (mean) FTE, by(panel_ID treated)
table treated, stat(mean FTE) stat (sd FTE)

restore