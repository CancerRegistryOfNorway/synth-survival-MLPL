

do "${root}\stata\settings.do"
do "${root}\stata\macros.do"

loc type = "${site}_ims"
import delim using "${root}\python\export\\`type'.csv", delim(";") clear

gen s = _n

reshape long v, i(s) j(model)

replace model = model-1

rename v ims
replace ims = ims*100

collapse (median) med=ims (p25) p25=ims (p75) p75=ims, by(model)

tostring med, format(%5.3f) replace force
tostring p25, format(%5.3f) replace force
tostring p75, format(%5.3f) replace force

gen ims = med + " (" + p25 + ", " + p75 + ")"

keep model ims

save "${results}\data\ims_${site}_sum.dta", replace

