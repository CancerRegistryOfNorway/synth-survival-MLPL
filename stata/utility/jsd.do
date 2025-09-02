clear mata

mata
function JSdist(string scalar newmat){
	numeric matrix P
	numeric matrix Q
	numeric matrix M
	numeric scalar js
	
	P = st_matrix(newmat)[.,1]:/sum(st_matrix(newmat)[.,1])
	Q = st_matrix(newmat)[.,2]:/sum(st_matrix(newmat)[.,2])
	M = (P + Q)/2
	js = sqrt(0.5*sum(P:*log(P:/M)/log(2)) + 0.5*sum(Q:*log(Q:/M)/log(2)))
	st_numscalar("r(jsd)", js)
}
end

set scheme white_tableau
graph set window fontface "Aptos"

local models = "`1'"
local i = 0

frames reset
frame create unires model sim str32(var) jsd

foreach mod of local models{
	forvalues s = 1/$nsim {
		use "${root}\original_data\original_${site}.dta", clear

		append using "${root}\simulated_data\simulated_`mod'`s'.dta", gen(synth)
		recode stage (. = 999)
		replace daar = year(diag_date)
		
		foreach v in age stage sex daar status _t {

			if inlist("`v'", "_t", "age") {
				qui su `v'
				loc width = (`r(max)' - `r(min)')/19
				gen `v'_grp = floor(`v'/`width')
				loc v `v'_grp
			}
			
			
			qui tabulate `v' synth, matcell(newmat)
			mata JSdist("newmat")
			loc jsd = `r(jsd)'
			
			frame post unires (`i') (`s') ("`v'") (`jsd') 
		}
	}
	loc ++i
}

frame unires {
	save "${results}\data\jsd.dta", replace
	
	use "${results}\data\jsd.dta", clear 
	
	lab define modlab 0 "Indep. marginals" 1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5" 6 "Resampling", replace
	label val model modlab
	
	collapse (sum) jsd, by(sim model)
	
	separate jsd, by(model)
	drop jsd

	# delim ;
	graph box jsd?, over(model, axis(fex)) hor name(jsd, replace) ytitle("Jensen-Shonnan difference (JSD)")  plotregion(margin(tiny)) legend(off) nofill 
	title("Univariate")
	box(1, fcolor(white)) marker(1, mcolor(black))
	box(2, fcolor("`.__SCHEME.color.p1'")) marker(2, mcolor("`.__SCHEME.color.p1'"))
	box(3, fcolor("`.__SCHEME.color.p2'")) marker(3, mcolor("`.__SCHEME.color.p2'"))
	box(4, fcolor("`.__SCHEME.color.p3'")) marker(4, mcolor("`.__SCHEME.color.p3'"))
	box(5, fcolor("`.__SCHEME.color.p4'")) marker(5, mcolor("`.__SCHEME.color.p4'"))
	box(6, fcolor("`.__SCHEME.color.p5'")) marker(6, mcolor("`.__SCHEME.color.p5'"))
	box(7, fcolor(white)) marker(7, mcolor(black))
	;
	# delim cr
	graph display, xsize(4.5)
	
	graph save "${results}\utility\jsd.gph", replace
	
}


use "${results}\data\jsd.dta", clear 
collapse (sum) jsd, by(sim model)
collapse (median) med=jsd (p25) p25=jsd (p75) p75=jsd, by(model)

replace med = round(med, 0.001)
replace p25 = round(p25, 0.001)
replace p75 = round(p75, 0.001)

tostring med p25 p75, replace force format(%4.3f)

gen jsd = med + " (" + p25 + ", " + p75 + ")"

keep model jsd

save "${results}\data\jsd_sum.dta", replace