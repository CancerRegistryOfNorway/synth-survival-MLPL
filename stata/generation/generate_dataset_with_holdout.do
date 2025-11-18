args mod i

* Define necessary macros for session
global root "..." /*Insert path to main folder */
do "${root}\stata\macros.do"
do "${root}\stata\settings.do"

* Get model properties
do "${root}\stata\models.do" "`mod'"

* New seed per session
set seed `=`i'*(max(`mod',1))'

* Generate synthetic data
use "${root}\original_data\holdout\original_holdout_${site}_`i'.dta", clear
local N = _N

keep if holdout == 0
drop holdout

capt _return drop synth_sequential_models
synth_sequential_models_stpm3, sample_beta 											///
	sequence(${sequence})															///
	continuous(age) continuous_winsor(${winsor}) continuous_df(${dfcont}) 			///
	diag_year(${daar_var}) diag_year_grp_length(${daar_grp_length})					///
	stpm3_tvc(${tvc}) ${stpm3_dftvc} stpm3_df(${df})								///
	simulated_count(`N') 															///
	level(${level}) interactions(${interactions}) interactions_3w(${interaction_3w}) ///
	censoring_date(${censoring_date}) 												///	
	save("${root}\simulated_data\holdout\simulated_holdout_${name}`i'.dta")

* Format synthetic data
do "${dataprep}\dataclean.do" "\holdout\simulated_holdout_${name}`i'" "${sequence}"

* Export to csv
use "${root}\simulated_data\holdout\simulated_holdout_${name}`i'.dta", clear
label drop _all

outsheet id $sequence diag_date status exit _t using "${root}\python\input\simulated_holdout_${name}`i'.csv", comma replace  
