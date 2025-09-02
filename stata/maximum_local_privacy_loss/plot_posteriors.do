capt frame change default
capt frame drop results
frame create results model sim bayesian ll_diff bayesian_max

set scheme white_tableau
graph set window fontface "Arial"

* Plot maxial local privacy loss

local models = "${prefix}margins ${prefix}main ${prefix}inter_agestage ${prefix}inter_agestagesex ${prefix}inter_agestagesex3w ${prefix}inter_agestagesex3w_df8"
local i = 0

foreach mod of local models{	
	forvalues s = 1/$nsim {
		
		use "${data}\privacy_risk\risk_stage_`mod'`s'.dta", clear
		su probability if correct
		loc bayesian = `r(max)' 
		
		su probability 
		loc bayesian_max = `r(max)' 
		
		bysort id (CU_i_logZ_all) : gen LL_diff = CU_i_logZ_all[_N] - CU_i_logZ_all[1]
		su LL_diff
		if (`r(N)' == 0) continue
		loc ll_diff = `r(max)' 
		
		frame post results (`i') (`s') (`bayesian') (`ll_diff') (`bayesian_max')
	}
	local ++i
}

frame results {
	save "${results}\data\dp_audit_${site}.dta", replace
}

use "${results}\data\dp_audit_${site}.dta", clear
lab define modlab 0 "Indep. marginals" 1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5", replace
label val model modlab

if ("$site" == "colon") {
	loc title = "Colon"
	loc ylab = "ylab(0(1)4)"
}
else {
	loc title = "Pancreas"
	loc ylab = "ylab(0(5)45)"
}

# delim ;
graph box ll_diff, over(model, axis(fex)) hor name(ll_diff, replace) ytitle("{it:L{sub:Z}(Y)}")  plotregion(margin(tiny)) legend(off) nofill `ylab'
title("`title'")
box(1, fcolor(*0.7)) marker(1, mcolor(*0.7))
;
# delim cr
graph display, xsize(4.5) ysize(3) scale(*1.2)

graph save "${results}\privacy\dp_audit_${site}.gph", replace

* Plot posteriors

use "${results}\data\dp_audit_${site}.dta", clear

lab define modlab 0 "Marginals" 1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5" 6 "Model 6"
label val model modlab

frame results: egen med = median(ll_diff), by(model)
frame results: gen med_dist = abs(ll_diff-med)
frame results: bysort model (med_dist sim) : gen med_priv = (_n == 1)

local models = "${prefix}margins ${prefix}main ${prefix}inter_agestage ${prefix}inter_agestagesex ${prefix}inter_agestagesex3w ${prefix}inter_agestagesex3w_df8"

loc medblue = "`.__SCHEME.color.p1'"
local m = 0
foreach mod in `models'{
	di "`mod'"
	frame results : su sim if model == `m' & med_priv
	local s = `r(mean)'
	
	use "${data}\privacy_risk\risk_stage_`mod'`s'.dta", clear
	bysort id (CU_i_logZ_all) : gen LL_diff = CU_i_logZ_all[_N] - CU_i_logZ_all[1]
	gen prior_uninformed = 0.25

	sort LL_diff
	keep if id == id[_N]

	expand 102, gen(j)

	bysort j stage : gen a_n = _n-1 if j == 1

	gen a4 = round(a_n/100,0.01)
	expand 3 if j == 1

	bysort j stage a4 : gen a1 = (1-a4)*(_n == 1)
	bysort j stage a4 (a1) : gen a2 = (1-a4)*(_n == 1)
	bysort j stage a4 (a1 a2) : gen a3= (1-a4)*(_n == 1)

	bysort j stage (a1 a2 a3 a4) : gen plot_a = _n if j == 1
	
	gen prior_a = .
	loc i = 1
	forvalues s = 1/4{
		if (`s' == 4) loc stg = 999
		else loc stg = `s'
		
		su correct if stage == `stg'
		
		if (`r(mean)' == 1) replace prior_a = a4 if stage == `stg'
		else {
			replace prior_a = a`i' if stage == `stg'
			loc ++i
		}
	}

	gen r_a = probability * prior_a
	egen tota = total(r_a), by(plot_a)
	replace r_a = r_a / tota

	bysort j a4 (correct a1 a2 a3): gen y1 = r_a[_N]
	bysort j a4 (correct a1 a2 a3): gen y2 = r_a[_N-1]
	bysort j a4 (correct a1 a2 a3): gen y3 = r_a[_N-2]

	bysort j a4 (correct a1 a2 a3): drop if !correct & j == 1
	bysort j a4 (correct a1 a2 a3): drop if _n > 1 & j == 1
	
	egen ymin = rowmin(y1 y2 y3)
	egen ymax = rowmax(y1 y2 y3)
	
	tostring LL_diff, format(%3.2f) generate(ll_string) force
	
	loc ll_diff = ll_string[1]

	
	if (`m' == 0) loc titl = "{bf:Indep. marginals:} L{sub:Z}(Y) = `ll_diff'"
	else loc titl = "{bf:Model `m':} L{sub:Z}(Y) = `ll_diff'"
	
	su probability if correct 
	loc probability `r(mean)' 
	loc problab : di %4.2f `r(mean)' 
	di `probability'
	di "`problab'"
	replace ymin = max(ymax-0.01,0) if ymax-ymin <0.01
	
	# delim ;
	tw 	
		(rarea ymin ymax prior_a if j == 1, sort col(`medblue') col(*0.5) lwidth(none))
		
		(scatteri `probability' 0.25, msymbol(X) mcolor("`medblue'") msize(*1.2))
		(scatteri `probability' 0 `probability' 0.25, recast(line) lcolor("`medblue'") lwidth(*0.7))
		(scatteri 0 0.25 `probability' 0.25, recast(line) lcolor("`medblue'") lwidth(*0.7))
		
		(scatteri `probability' 0 (2) "`problab'", msymbol(i) mlabcolor("`medblue'"))
		(scatteri 0 0.25 (2) "0.25", msymbol(i) mlabcolor("`medblue'"))
		
		(scatteri 0 0 1 1, recast(line) lcolor(black) lpattern(dash))
			
	,
	title("`titl'", size(medsmall))
	xtitle("Prior") xscale(range(0 1))
	ytitle("Posterior")
	legend(order(1 "All possible priors" 2 "Uniform prior") rows(1) pos(6))
	
	plotregion(margin(zero))
	name(`mod', replace)
	;
	# delim cr
	local ++m
}

grc1leg ${prefix}margins ${prefix}main ${prefix}inter_agestage ${prefix}inter_agestagesex ${prefix}inter_agestagesex3w ${prefix}inter_agestagesex3w_df8, title("Probability assigned to correct outcome", size(medsmall)) name(max, replace) rows(2) 

graph export "${results}\export\privacy_evaluation_prob_${site}.pdf", replace
graph export "${results}\export\privacy_evaluation_prob_${site}.eps", replace 
graph export "${results}\export\privacy_evaluation_prob_${site}.tif", replace width(4800)
