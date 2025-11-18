clear mata

mata
function PCD(string scalar orig, string scalar sim){
	numeric matrix D
	numeric scalar pcd
	
	D = st_matrix(orig) - st_matrix(sim)
	pcd = sqrt(sum(trace(D*D')))
	st_numscalar("r(pcd)", pcd)
}
end

set scheme white_tableau
graph set window fontface "Aptos"

local models = "`1'"
local i = 0

frames reset
frame create bires model sim pcd

matrix id = I(4)

foreach mod of local models{
	forvalues s = 1/$nsim {
		use "${root}\original_data\original_${site}.dta", clear

		append using "${root}\simulated_data\simulated_`mod'`s'.dta", gen(synth)
		recode stage (. = 4) (999 = 4)
		replace daar = year(diag_date)
		
		qui tab stage, gen(stageN)
		
		qui correlate stageN? age daar sex _t status if synth == 0
		matrix orig = r(C)
		matrix orig[1, 1] = id
		
		qui correlate stageN? age daar sex _t status if synth == 1
		matrix sim = r(C)
		matrix sim[1, 1] = id
	
		mata PCD("orig","sim")
		loc pcd = `r(pcd)'
			
		frame post bires (`i') (`s') (`pcd') 
	}
	loc ++i
}

frame bires {
	save "${results}\data\pcd.dta", replace
	
	use "${results}\data\pcd.dta", clear
	lab define modlab 0 "Indep. marginals" 1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5" 6  "Resampling", replace
	label val model modlab
	
	separate pcd, by(model)
	drop pcd
	
	
	loc lim = 0.1
	loc gge = ustrunescape("\u226B")

	assert pcd0 > `lim'
	qui su pcd0
	loc min0 = round(`r(min)',0.01)
	loc max0 = substr("`=round(`r(max)',0.01)'",1,3)
	_pctile pcd0, p(50)
	loc med0 = substr("`=round(`r(r1)',0.01)'",1,3)
	replace pcd0 = `lim' if model == 0

	# delim ;
	graph box pcd?, over(model, axis(fex)) hor name(pcd, replace) ytitle("Pairwise correlation difference (PCD)")  plotregion(margin(tiny)) legend(off) nofill 
	title("Bivariate") yscale(range(0 0.1)) ylab(0(0.025)0.1)
	box(1, fcolor(none) lcolor(none)) marker(1, mcolor(none)) 
	box(2, fcolor("`.__SCHEME.color.p1'")) marker(2, mcolor("`.__SCHEME.color.p1'"))
	box(3, fcolor("`.__SCHEME.color.p2'")) marker(3, mcolor("`.__SCHEME.color.p2'"))
	box(4, fcolor("`.__SCHEME.color.p3'")) marker(4, mcolor("`.__SCHEME.color.p3'"))
	box(5, fcolor("`.__SCHEME.color.p4'")) marker(5, mcolor("`.__SCHEME.color.p4'"))
	box(6, fcolor("`.__SCHEME.color.p5'")) marker(6, mcolor("`.__SCHEME.color.p5'"))
	box(7, fcolor(white)) marker(7, mcolor(black))
	
	text(0.00 96  "PCD = 0`med0'(0`min0' - 0`max0')", size(small) place(3))
	;
	# delim cr
	graph display, xsize(4.5)
	
	graph save "${results}\utility\pcd_lim.gph", replace
}


use "${results}\data\pcd.dta", clear
lab define modlab 0 "Indep. marginals" 1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5" 6 "Resampling", replace
label val model modlab

separate pcd, by(model)
drop pcd

# delim ;
graph box pcd?, over(model, axis(fex)) hor name(pcd, replace) ytitle("Pairwise correlation difference (PCD)")  plotregion(margin(tiny)) legend(off) nofill 
title("Bivariate")
box(1, fcolor(none) ) marker(1, mcolor(black)) 
box(2, fcolor("`.__SCHEME.color.p1'")) marker(2, mcolor("`.__SCHEME.color.p1'"))
box(3, fcolor("`.__SCHEME.color.p2'")) marker(3, mcolor("`.__SCHEME.color.p2'"))
box(4, fcolor("`.__SCHEME.color.p3'")) marker(4, mcolor("`.__SCHEME.color.p3'"))
box(5, fcolor("`.__SCHEME.color.p4'")) marker(5, mcolor("`.__SCHEME.color.p4'"))
box(6, fcolor("`.__SCHEME.color.p5'")) marker(6, mcolor("`.__SCHEME.color.p5'"))
box(7, fcolor(white)) marker(7, mcolor(black))

;
# delim cr
graph display, xsize(4.5)

graph save "${results}\utility\pcd.gph", replace


use "${results}\data\pcd.dta", clear 
collapse (sum) pcd, by(sim model)
collapse (median) med=pcd (p25) p25=pcd (p75) p75=pcd, by(model)

replace med = round(med, 0.001)
replace p25 = round(p25, 0.001)
replace p75 = round(p75, 0.001)

tostring med p25 p75, replace force format(%5.3f)

gen pcd = med + " (" + p25 + ", " + p75 + ")"

keep model pcd

save "${results}\data\pcd_sum.dta", replace