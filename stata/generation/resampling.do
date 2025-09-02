

forvalues i = 1/$nsim {
	
	use "${root}\original_data\original_${site}.dta", clear
	local N = _N

	bsample `N'
	
	save "${root}\simulated_data\simulated_${prefix}dummy`i'.dta", replace
	
	label drop _all
	outsheet id $sequence diag_date status exit _t using "${root}\python\input\simulated_${prefix}dummy`i'.csv", comma replace  
}
