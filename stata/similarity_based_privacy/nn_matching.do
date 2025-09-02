
local models = "`1'"

* Normalize datasets: 

use "${root}\original_data\original_${site}.dta", clear
keep id stage sex age diag_date  _t status 

tabulate stage, gen(stageN)
drop stage stageN4

foreach v of varlist * {
	if ("`v'" == "id") continue
	su `v'
	loc `v'_mean = `r(mean)'
	loc `v'_std = `r(sd)'
	gen `v'_std = (`v' - ``v'_mean')/``v'_std'
}

save "${root}\original_data\original_${site}_std.dta", replace

foreach mod of local models{
	forvalues s = 1/$nsim {
		use "${root}\simulated_data\simulated_`mod'`s'.dta", clear
		keep stage sex age diag_date  _t status  id
		recode stage (. = 999)

		tabulate stage, gen(stageN)
		drop stage stageN4

		foreach v of varlist * {
			if ("`v'" == "id") continue
			gen `v'_std = (`v' - ``v'_mean')/``v'_std'
		}

		save "${root}\simulated_data\standardized\simulated_`mod'`s'_std.dta", replace
	}
}

* NN-match: 

foreach mod of local models{
	forvalues s = 1/$nsim {
		use "${root}\simulated_data\standardized\simulated_`mod'`s'_std.dta", replace

		append using "${root}\original_data\original_${site}_std.dta", gen(orig)

		gen ovar = 1

		teffects nnmatch (ovar *_std) (orig), metric(eucl) nn(1) generate(match)

		gen n = _n

		keep id n *_std match1 orig
		rename match1 match_n

		preserve
		keep if orig == 0
		keep id n *_std match_n

		save  "${data}\dcr\nn_synth_orig_`mod'`s'.dta", replace
		restore 

		keep if orig == 1
		keep id n *_std match_n

		save  "${data}\dcr\nn_orig_synth_`mod'`s'.dta", replace
	}
}