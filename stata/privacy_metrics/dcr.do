
do "${root}\stata\settings.do"
do "${root}\stata\macros.do"

loc type = "${site}_dcr"
import delim using "${root}\python\export\\`type'.csv", delim(";") clear

gen s = _n

reshape long v, i(s) j(model)

replace model = model-1

rename v dcr

collapse (median) med=dcr (p25) p25=dcr (p75) p75=dcr, by(model)

tostring med, format(%5.3f) replace force
tostring p25, format(%5.3f) replace force
tostring p75, format(%5.3f) replace force

gen dcr = med + " (" + p25 + ", " + p75 + ")"

keep model dcr

save "${results}\data\dcr_${site}_sum.dta", replace

