
set scheme white_tableau
graph set window fontface "Aptos"

local models = "`1'"
local i = 0

frames reset
frame create survres model sim med_diff mean_diff

foreach mod of local models{
	forvalues s = 1/$nsim {
		di "`i';`s'"

		use "${root}\original_data\original_${site}.dta", clear

		append using "${root}\simulated_data\simulated_`mod'`s'.dta", gen(synth)
		recode stage (. = 999)

		gen age_grp = irecode(age, 0, 40, 50, 60, 70, 80)
		
		egen grp = group(age_grp sex stage)

		qui sts list , survival riskt(0 5) by( grp synth) saving("${results}\data\surv_tmp.dta", replace)
		use "${results}\data\surv_tmp.dta", clear
		
		replace survivor = 0 if mi(survivor)

		keep if time == 5
		keep  grp synth survivor
		bysort grp (synth) : gen abs_diff = abs(survivor[1] - survivor[2])
		keep if synth == 0
		su abs_diff
		loc m = `r(mean)'
		_pctile abs_diff, p(50)

		frame post survres (`i') (`s') (`r(r1)') (`m')
	}
	local ++i
}

frame survres {
	save "${results}\data\5yr_surv.dta", replace
	
	use "${results}\data\5yr_surv.dta", clear
	lab define modlab 0 "Indep. marginals" 1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5" 6 "Resampling"
	label val model modlab
	
	separate mean_diff, by(model)
	drop mean_diff
	
	loc lim = 0.1
	loc gge = ustrunescape("\u226B")

	capt assert mean_diff0 > `lim'
	if _rc == 0 {
	qui su mean_diff0
	loc min0 = round(`r(min)',0.01)
	loc max0 = round(`r(max)',0.01)
	_pctile mean_diff0, p(50)
	loc med0 = substr("`=round(`r(r1)',0.01)'",1,3)
	replace mean_diff0 = `lim' if model == 0

	# delim ;
	graph box mean_diff?, over(model, axis(fex)  ) hor name(mean_diff, replace) ytitle("Mean abs. diff. 5-year survival") plotregion(margin(tiny)) legend(off) nofill title("Survival")
	box(1, fcolor(none) lcolor(none)) marker(1, mcolor(none))
	box(2, fcolor("`.__SCHEME.color.p1'")) marker(2, mcolor("`.__SCHEME.color.p1'"))
	box(3, fcolor("`.__SCHEME.color.p2'")) marker(3, mcolor("`.__SCHEME.color.p2'"))
	box(4, fcolor("`.__SCHEME.color.p3'")) marker(4, mcolor("`.__SCHEME.color.p3'"))
	box(5, fcolor("`.__SCHEME.color.p4'")) marker(5, mcolor("`.__SCHEME.color.p4'"))
	box(6, fcolor("`.__SCHEME.color.p5'")) marker(6, mcolor("`.__SCHEME.color.p5'"))
	box(7, fcolor(white)) marker(7, mcolor(black))
	
	text(0.00 96  "Diff = 0`med0'(0`min0' - 0`max0')", size(small) place(3))
	yscale(range(0 0.1)) ylab(0(0.02)0.1)
	;
	# delim cr
	graph display, xsize(4.5)
	
	graph save "${results}\utility\5yr_surv_lim.gph", replace
	}
	
}

use "${results}\data\5yr_surv.dta", clear
lab define modlab 0 "Indep. marginals" 1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5" 6  "Resampling"
label val model modlab

separate med_diff, by(model)
drop med_diff

# delim ;
graph box med_diff?, over(model, axis(fex)  ) hor name(med_diff, replace) ytitle("Mean abs. diff. 5-year survival") plotregion(margin(tiny)) legend(off) nofill title("Survival")
box(1, fcolor(none)) marker(1, mcolor(black))
box(2, fcolor("`.__SCHEME.color.p1'")) marker(2, mcolor("`.__SCHEME.color.p1'"))
box(3, fcolor("`.__SCHEME.color.p2'")) marker(3, mcolor("`.__SCHEME.color.p2'"))
box(4, fcolor("`.__SCHEME.color.p3'")) marker(4, mcolor("`.__SCHEME.color.p3'"))
box(5, fcolor("`.__SCHEME.color.p4'")) marker(5, mcolor("`.__SCHEME.color.p4'"))
box(6, fcolor("`.__SCHEME.color.p5'")) marker(6, mcolor("`.__SCHEME.color.p5'"))
box(7, fcolor(white)) marker(7, mcolor(black))
;
# delim cr
graph display, xsize(4.5)

graph save "${results}\utility\5yr_surv.gph", replace

use "${results}\data\5yr_surv.dta", clear 
collapse (sum) mean_diff, by(sim model)
collapse (median) med=mean_diff (p25) p25=mean_diff (p75) p75=mean_diff, by(model)

replace med = round(med, 0.001)
replace p25 = round(p25, 0.001)
replace p75 = round(p75, 0.001)

tostring med p25 p75, replace force format(%5.3f)

gen mean_diff = med + " (" + p25 + ", " + p75 + ")"

keep model mean_diff

save "${results}\data\5yr_sum.dta", replace