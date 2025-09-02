
local models = "`1'"

use "${root}\original_data\original_${site}_std.dta", clear

append using "${root}\original_data\original_${site}_std.dta", gen(orig2)

gen ovar = 1

teffects nnmatch (ovar *_std) (orig2), metric(eucl) nn(2) generate(match)

gen n = _n

count if orig2 == 0
replace match1 = match1- r(N)
replace match2 = match2- r(N)

keep if orig2 == 0

replace match2 = match1 if match2 == n

keep n *_std match2 id

tempfile orig_n
save `orig_n'

rename * *_orig
rename _t_std _t_std_orig

rename match2_orig n
drop n_orig

merge m:1 n using `orig_n', keep(match master) assert(match using) nogen

gen s = 0
foreach v of varlist *_std{
	replace s = s + (`v' - `v'_orig)^2
}
replace s = sqrt(s)

keep id_orig s
rename id_orig id

save "${data}\dcr\dcr_orig_${site}.dta", replace


// Distances orig -> synth
foreach mod of local models{
	forvalues s = 1/$nsim {
		use "${data}\dcr\nn_orig_synth_`mod'`s'.dta", clear
		
		rename * *_orig
		rename _t_std _t_std_orig

		drop n_orig
		rename match_n_orig n

		merge m:1 n using "${data}\dcr\nn_synth_orig_`mod'`s'.dta", keep(match master) assert(match using) nogen
		
		gen s = 0
		foreach v of varlist *_std{
			replace s = s + (`v' - `v'_orig)^2
		}
		replace s = sqrt(s)
		
		keep id_orig s
		rename id_orig id
		
		save "${data}\dcr\dcr_orig_`mod'`s'.dta", replace
	}
}

frames reset
frame create id_score model sim dcr

loc i = 0
foreach mod of local models{
	forvalues s = 1/$nsim {
		use "${data}\dcr\dcr_orig_${site}.dta", clear
		rename s s_orig
		merge 1:1 id using "${data}\dcr\dcr_orig_`mod'`s'.dta"
		
		gen synth_closer = (s < s_orig)
		su synth_closer

		frame post id_score (`i') (`s') (`r(mean)') 
	}
	loc ++i
}

frame change id_score
save "${results}\data\id_score_${site}.dta", replace



use "${results}\data\id_score_${site}.dta", clear

collapse (median) med=dcr (p25) p25=dcr (p75) p75=dcr, by(model)

replace med = round(med, 0.001)
replace p25 = round(p25, 0.001)
replace p75 = round(p75, 0.001)

tostring med p25 p75, replace force format(%5.3f)

replace med = substr(med,1,5)
replace p25 = substr(p25,1,5)
replace p75 = substr(p75,1,5)

gen ids = med + " (" + p25 + ", " + p75 + ")"

keep model ids

save "${results}\data\id_score_${site}_sum.dta", replace
