*===============================================================================
* master.do - Floods and local labour markets: the 2017 KwaZulu-Natal flood
*
* Runs the full pipeline. From Stata:
*     cd "<path to this repository>"
*     do master.do
*
* Data location: by default the raw data are expected in data/raw/ (see
* data/README.md). To use another folder, copy config_local.example.do to
* config_local.do (git-ignored) and set $raw there.
*===============================================================================
version 18
clear all
set more off

*--- Paths ----------------------------------------------------------------------
global root   "`c(pwd)'"
global raw    "$root/data/raw"          // Spatial Tax Panel CSVs + shapefiles
global work   "$root/data/work"         // intermediate .dta files (git-ignored)
global output "$root/output"            // tables, figures, log (git-ignored)
global code   "$root/code"

capture confirm file "$code/01_build_industry.do"
if _rc {
    di as error "Run master.do from the repository root (cd to the folder that contains master.do)."
    exit 601
}
capture confirm file "$root/config_local.do"     // optional local overrides
if !_rc include "$root/config_local.do"

capture mkdir "$root/data"
capture mkdir "$work"
capture mkdir "$output"

*--- Packages (SSC) -------------------------------------------------------------
* psmatch2 (incl. pstest, psgraph), reghdfe (+ ftools, require), estout
* (esttab, eststo, estpost), outreg2, geodist, spmap
global install_packages 1
if $install_packages {
    foreach p in psmatch2 ftools require reghdfe estout outreg2 geodist spmap {
        capture which `p'
        if _rc ssc install `p', replace
    }
}

*--- Reproducibility --------------------------------------------------------------
* xtdidregress, wildbootstrap (09_robustness.do) draws random numbers
set seed 20170501

*--- Control group ----------------------------------------------------------------
* "thesis": the 24 matched municipalities used in the thesis (reproduces its dataset)
* "psm"   : the control group produced by code/04_psm_controls.do as written
global controls "thesis"

*--- Run --------------------------------------------------------------------------
* spshape2dta, grmap and spmap look for the _shp file in the current folder
cd "$work"
capture log close _all
log using "$output/master.log", replace text name(master)

do "$code/01_build_industry.do"     // monthly FTE by industry   -> New_monthly_industry.dta
do "$code/02_build_inputs.do"       // FTE, imports, income, map  -> input .dta files
do "$code/03_build_panel.do"        // municipality-month panel   -> panel_full.dta
do "$code/04_psm_controls.do"       // propensity-score matching  -> matched_municipalities.dta (used if $controls == "psm")
do "$code/05_did_sample.do"         // matched DiD sample         -> analysis_panel.dta
do "$code/06_descriptives.do"       // summary statistics tables
do "$code/07_main_did.do"           // main DiD results           -> DIDresults.rtf
do "$code/08_sector_did.do"         // sector DiD results         -> Sectors.rtf
do "$code/09_robustness.do"         // robustness checks

log close master
cd "$root"
di as result "Done. Outputs are in $output"
