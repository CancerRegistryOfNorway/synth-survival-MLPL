
local models = "`1'"

foreach mod of local models{
	forvalues s = 1/$nsim {
		
		use "${data}\dcr\nn_synth_orig_`mod'`s'.dta", clear

		rename * *_synth
		rename _t_std _t_std_synth

		drop n_synth
		rename match_n_synth n

		merge m:1 n using "${data}\dcr\nn_orig_synth_`mod'`s'.dta", keep(match master) assert(match using) nogen

		gen s = 0
		foreach v of varlist *_std{
			replace s = s + (`v' - `v'_synth)^2
		}
		replace s = sqrt(s)
		
		keep id_synth s
		rename id_synth id
		
		save "${data}\dcr\dcr_`mod'`s'.dta", replace
	}
}

frames reset
frame create dcr_synth model sim dcr

loc i = 0
foreach mod of local models{
	forvalues s = 1/$nsim {
		use "${data}\dcr\dcr_`mod'`s'.dta", clear
		collapse (mean) s
		
		frame post dcr_synth (`i') (`s') (`=s[1]') 
	}
	loc ++i
}

frame change dcr_synth
save "${results}\data\dcr_${site}.dta", replace

use "${results}\data\dcr_${site}.dta", clear

collapse (median) med=dcr (p25) p25=dcr (p75) p75=dcr, by(model)

replace med = round(med, 0.001)
replace p25 = round(p25, 0.001)
replace p75 = round(p75, 0.001)

tostring med p25 p75, replace force format(%5.3f)

replace med = substr(med,1,5)
replace p25 = substr(p25,1,5)
replace p75 = substr(p75,1,5)

gen dcr = med + " (" + p25 + ", " + p75 + ")"

keep model dcr

save "${results}\data\dcr_${site}_sum.dta", replace
