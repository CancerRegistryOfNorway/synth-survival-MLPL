
local models = "`1'"
local i = 0

frames reset
frame create ims_res model sim ims

foreach mod of local models{
	forvalues s = 1/$nsim {
		
		
		use "${root}\simulated_data\simulated_`mod'`s'.dta", clear
		
		keep stage sex age diag_date _t status id
		recode stage (. = 999)

		joinby stage sex age diag_date  _t status using "${root}\original_data\original_${site}.dta", unmatched(master) 
		bysort id : keep if _n == 1
		fre _merge
		gen match = (_merge == 3)
		su match
		
		frame post ims_res (`i') (`s') (`r(mean)') 
		
	}
	local ++i
}

frame change ims_res
save "${results}\data\ims_${site}.dta", replace


use "${results}\data\ims_${site}.dta", clear
replace ims = ims*100

collapse (median) med=ims (p25) p25=ims (p75) p75=ims, by(model)

replace med = round(med, 0.001)
replace p25 = round(p25, 0.001)
replace p75 = round(p75, 0.001)

tostring med p25 p75, replace force format(%5.3f)

replace med = substr(med,1,5)
replace p25 = substr(p25,1,5)
replace p75 = substr(p75,1,5)

gen ims = med + " (" + p25 + ", " + p75 + ")"

keep model ims

save "${results}\data\ims_${site}_sum.dta", replace
