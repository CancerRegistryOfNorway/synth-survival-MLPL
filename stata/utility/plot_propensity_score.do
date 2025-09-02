
do "${root}\stata\settings.do"
do "${root}\stata\macros.do"

loc type = "${site}_propensity_score"

import delim using "${root}\python\export\\`type'.csv", delim(";") clear

gen s = _n

reshape long v, i(s) j(model)

replace model = model-1
save "${results}\data\\`type'.dta", replace

separate v, by(model)
drop v

lab define modlab 0 "Indep. marginals" 1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5" 6 "Resampling"
label val model modlab

loc lim = 0.005
loc gge = ustrunescape("\u226B")

assert v0 > `lim'
qui su v0
loc min0 = round(`r(min)',0.001)
loc max0 = round(`r(max)',0.001)
_pctile v0, p(50)
loc med0 = round(`r(r1)',0.001)
replace v0 = `lim' if model == 0

# delim ;
graph box v? , over(model, axis(fex)  ) hor name("`type'", replace) ytitle("Propensity score (pMSE)")  plotregion(margin(tiny)) legend(off) nofill title("Multivariate") yscale(range(0 `lim')) ylab(0(0.001)`lim')
box(1, fcolor(none) lcolor(none)) marker(1, mcolor(none)) miss
box(2, fcolor("`.__SCHEME.color.p1'")) marker(2, mcolor("`.__SCHEME.color.p1'"))
box(3, fcolor("`.__SCHEME.color.p2'")) marker(3, mcolor("`.__SCHEME.color.p2'"))
box(4, fcolor("`.__SCHEME.color.p3'")) marker(4, mcolor("`.__SCHEME.color.p3'"))
box(5, fcolor("`.__SCHEME.color.p4'")) marker(5, mcolor("`.__SCHEME.color.p4'"))
box(6, fcolor("`.__SCHEME.color.p5'")) marker(6, mcolor("`.__SCHEME.color.p5'"))
box(7, fcolor(white)) marker(7, mcolor(black))

text(0.00 96  "pMSE = 0`med0'(0`min0' - 0`max0')", size(small) place(3))
;
# delim cr
graph display, xsize(4.5)

graph save "${results}\utility\\`type'_lim.gph", replace

use "${results}\data\\`type'.dta", clear

separate v, by(model)
drop v

lab define modlab 0 "Indep. marginals" 1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5" 6 "Resampling"
label val model modlab

# delim ;
graph box v? , over(model, axis(fex)  ) hor name("`type'", replace) ytitle("Propensity score (pMSE)")  plotregion(margin(tiny)) legend(off) nofill title("Multivariate")
box(1, fcolor(none)) marker(1, mcolor(black)) miss
box(2, fcolor("`.__SCHEME.color.p1'")) marker(2, mcolor("`.__SCHEME.color.p1'"))
box(3, fcolor("`.__SCHEME.color.p2'")) marker(3, mcolor("`.__SCHEME.color.p2'"))
box(4, fcolor("`.__SCHEME.color.p3'")) marker(4, mcolor("`.__SCHEME.color.p3'"))
box(5, fcolor("`.__SCHEME.color.p4'")) marker(5, mcolor("`.__SCHEME.color.p4'"))
box(6, fcolor("`.__SCHEME.color.p5'")) marker(6, mcolor("`.__SCHEME.color.p5'"))
box(7, fcolor(white)) marker(7, mcolor(black))
;
# delim cr
graph display, xsize(4.5)

graph save "${results}\utility\\`type'.gph", replace


use "${results}\data\\`type'.dta", clear 
rename v pmse

collapse (median) med=pmse (p25) p25=pmse (p75) p75=pmse, by(model)

tostring med, format(%10.1e) replace force
tostring p25, format(%10.1e) replace force
tostring p75, format(%10.1e) replace force

gen pmse = med + " (" + p25 + ", " + p75 + ")"

keep model pmse

save "${results}\data\pmse_sum.dta", replace