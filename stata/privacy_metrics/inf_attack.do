
do "${root}\stata\settings.do"
do "${root}\stata\macros.do"

loc type = "${site}_inf_attack_fpr"

import delim using "${root}\python\export\\`type'.csv", delim(";") clear

gen s = ceil(_n/4)
rename v1 stage
reshape long v, i(s stage) j(model)
replace model = model-1

replace model = model-1
save "${results}\data\\`type'.dta", replace

loc type = "${site}_inf_attack_fpr_holdout"

import delim using "${root}\python\export\\`type'.csv", delim(";") clear

gen s = ceil(_n/4)
rename v1 stage
reshape long v, i(s stage) j(model)
replace model = model-1

replace model = model-1
save "${results}\data\\`type'.dta", replace

use "${results}\data\\${site}_inf_attack_fpr.dta", clear 
rename v tpr

merge 1:1 s stage model using "${results}\data\\${site}_inf_attack_fpr_holdout.dta", nogen 
gen relative = (tpr-v)/(1-v)

collapse (mean) mean_abs=tpr mean_rel=relative, by(model stage)

rename mean_abs mean0
rename mean_rel mean1

reshape long mean, i(stage model) j(type)

tostring mean, format(%5.3f) replace force

replace stage = stage + 10*type
drop type

reshape wide mean, i(model) j(stage)

order model mean1 mean11 mean2 mean12 mean3 mean13 mean9 mean19


lab define modlab 0 "Indep. marginals" 1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5" 6  "Resampling"
label val model modlab
decode model, gen(mod)

gen str =  " & " + mod + " & " + mean1 + " & "+ mean11 + " & " + mean2 + " & " + mean12 + " & " + mean3 +  " & " + mean13 + " & "+ mean9 + " & " + mean19 + " \\"
keep str

export delimited using ${results}\export\inf_attack_${site}.txt, delimiter(tab) novarnames replace
