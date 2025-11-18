
forvalues i = 1/$nsim {
	use "${root}\original_data\holdout\original_holdout_${site}_`i'.dta", clear
	loc N = _N

	keep if holdout == 0

	expand 2

	bsample `N'
	
	save "${root}\simulated_data\holdout\simulated_holdout_${prefix}dummy`i'.dta", replace
	
	label drop _all
	outsheet id $sequence diag_date status exit _t using "${root}\python\input\simulated_holdout_${prefix}dummy`i'.csv", comma replace  
}
