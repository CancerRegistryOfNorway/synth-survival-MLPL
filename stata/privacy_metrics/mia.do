
do "${root}\stata\settings.do"
do "${root}\stata\macros.do"


import delim using "${root}\python\export\\${site}_mia_ref_density_epsilon.csv", delim(";") clear

gen s = _n
gen metric = 1

reshape long v, i(s) j(model)

tempfile epsilon
save `epsilon'

import delim using "${root}\python\export\\${site}_mia_ref_density_fpr1.csv", delim(";") clear

gen s = _n
gen metric = 2

reshape long v, i(s) j(model)

tempfile fpr1
save `fpr1'

import delim using "${root}\python\export\\${site}_mia_ref_density_fpr2.csv", delim(";") clear

gen s = _n
gen metric = 3

reshape long v, i(s) j(model)

tempfile fpr2
save `fpr2'

import delim using "${root}\python\export\\${site}_mia_ref_density_fpr3.csv", delim(";") clear

gen s = _n
gen metric = 4

reshape long v, i(s) j(model)

tempfile fpr3
save `fpr3'

use `epsilon', clear
append using `fpr1'
append using `fpr2'
append using `fpr3'

replace model = model-1

collapse (median) med=v (min) p25=v (max) p75=v, by(model metric)

tostring med, format(%5.3f) replace force
tostring p25, format(%5.3f) replace force
tostring p75, format(%5.3f) replace force

gen value = med + " (" + p25 + ", " + p75 + ")"

drop med-p75

reshape wide value, i(model) j(metric)


lab define modlab 0 "Indep. marginals" 1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5" 6  "Resampling"
label val model modlab
decode model, gen(mod)

gen str = " & " + mod + " & "+ value1 + " & " + value2 + " & " + value3 + " & " + value4 + " \\"
keep str

export delimited using ${results}\export\mia_${site}.txt, delimiter(tab) novarnames replace
