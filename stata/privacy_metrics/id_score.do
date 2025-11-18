
do "${root}\stata\settings.do"
do "${root}\stata\macros.do"

loc type = "${site}_id_score"
import delim using "${root}\python\export\\`type'.csv", delim(";") clear

gen s = _n

reshape long v, i(s) j(model)

replace model = model-1

rename v id_score

collapse (median) med=id_score (p25) p25=id_score (p75) p75=id_score, by(model)

tostring med, format(%5.3f) replace force
tostring p25, format(%5.3f) replace force
tostring p75, format(%5.3f) replace force

gen id_score = med + " (" + p25 + ", " + p75 + ")"

keep model id_score

save "${results}\data\id_score_${site}_sum.dta", replace

