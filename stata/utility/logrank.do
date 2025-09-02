

set scheme white_tableau
graph set window fontface "Aptos"

local models = "`1'"
local i = 0

frames reset
frame create survres model sim p05

foreach mod of local models{
	di "`i'"
	forvalues s = 1/$nsim {

		use "${root}\original_data\original_${site}.dta", clear

		append using "${root}\simulated_data\simulated_`mod'`s'.dta", gen(synth)
		recode stage (. = 999)

		gen age_grp = irecode(age, 0, 40, 50, 60, 70, 80)
		
		capt frame change default
		capt frame drop survres1
		frame create survres1 p

		egen grp = group(stage sex age_grp)
		qui su grp
		forvalues g = 1/`r(max)' {
			qui sts test synth if grp == `g'
			loc p = chi2tail(`r(df)', `r(chi2)')
				
			frame post survres1 (`p') 
		}
		
		frame survres1 {
			gen p05 = (p < 0.05)
			su p05
			loc p05 = `r(mean)'
		}
		
		frame post survres (`i') (`s') (`p05') 
	}
	local ++i
}

frame survres {
	save "${results}\data\logrank.dta", replace
	
	use "${results}\data\logrank.dta", clear 
	lab define modlab 0 "Marginals" 1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5" 6 "Resampling"
	label val model modlab
	
	separate p05, by(model)
	drop p05

	# delim ;
	graph box p05?, over(model, axis(fex)  ) hor name(logrank, replace) ytitle("Share of p-values < 0.05") ylabel(0(0.1)1) yscale(range(0 1)) plotregion(margin(tiny)) legend(off) nofill title("Survival")
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
	
	graph save "${results}\utility\logrank.gph", replace
	
}

