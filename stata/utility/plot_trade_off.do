set scheme white_tableau
graph set window fontface "Aptos"

use "${results}\data\\${site}_propensity_score.dta", clear
rename s sim

merge 1:1 sim model using "${results}\data\dp_audit_${site}.dta"

egen mean_v = mean(v), by(model)
egen mean_ll = mean(ll_diff), by(model)

loc star = ustrunescape("\u2605")

# delim ;
tw
(scatter v ll_diff if model == 1, color(%50))
(scatter v ll_diff if model == 2, color(%50))
(scatter v ll_diff if model == 3, color(%50))
(scatter v ll_diff if model == 4, color(%50))
(scatter v ll_diff if model == 5, color(%50))

/* Centroides: */
(scatter mean_v mean_ll if model == 1 & sim == 1, msize(*2.5) mlcolor(black) mfcolor("`.__SCHEME.color.p1'"))
(scatter mean_v mean_ll if model == 2 & sim == 1, msize(*2.5) mlcolor(black) mfcolor("`.__SCHEME.color.p2'"))
(scatter mean_v mean_ll if model == 3 & sim == 1, msize(*2.5) mlcolor(black) mfcolor("`.__SCHEME.color.p3'"))
(scatter mean_v mean_ll if model == 4 & sim == 1, msize(*2.5) mlcolor(black) mfcolor("`.__SCHEME.color.p4'"))
(scatter mean_v mean_ll if model == 5 & sim == 1, msize(*2.5) mlcolor(black) mfcolor("`.__SCHEME.color.p5'"))

,
legend(order(1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5" ) rows(1) pos(6))
scale(*1.2)
xtitle("c(Z|D)")
ytitle("Propensity score (pMSE)")
name(propensity_tradeoff, replace)
;
# delim cr


use "${results}\data\5yr_surv.dta", clear

merge 1:1 sim model using "${results}\data\dp_audit_${site}.dta"

egen mean_mean_diff= mean(mean_diff), by(model)
egen mean_ll = mean(ll_diff), by(model)

# delim ;
tw

(scatter ll_diff mean_diff if model == 1, jitter(0) color(%50))
(scatter ll_diff mean_diff if model == 2, jitter(0) color(%50))
(scatter ll_diff mean_diff if model == 3, jitter(0) color(%50))
(scatter ll_diff mean_diff if model == 4, jitter(0) color(%50))
(scatter ll_diff mean_diff if model == 5, jitter(0) color(%50))


/* Centroides: */
/*
(scatter mean_ll mean_mean_diff if model == 1 & sim == 1, msize(*2.5) mlcolor(black) mfcolor("`.__SCHEME.color.p1'"))
(scatter mean_ll mean_mean_diff if model == 2 & sim == 1, msize(*2.5) mlcolor(black) mfcolor("`.__SCHEME.color.p2'"))
(scatter mean_ll mean_mean_diff if model == 3 & sim == 1, msize(*2.5) mlcolor(black) mfcolor("`.__SCHEME.color.p3'"))
(scatter mean_ll mean_mean_diff if model == 4 & sim == 1, msize(*2.5) mlcolor(black) mfcolor("`.__SCHEME.color.p4'"))
(scatter mean_ll mean_mean_diff if model == 5 & sim == 1, msize(*2.5) mlcolor(black) mfcolor("`.__SCHEME.color.p5'"))
*/
,
legend(order(1 "Model 1" 2 "Model 2" 3 "Model 3" 4 "Model 4" 5 "Model 5" ))
scale(*1.2) plotregion(margin(tiny))
ytitle("c(Z|D)") yscale(range(0 4)) ylab(0(1)4)
xtitle("Mean abs. diff. 5-year survival") xscale(range(0 0.07)) xlab(0(0.01)0.1)
name(surv_tradeoff_med, replace)
;
# delim cr


grc1leg propensity_tradeoff surv_tradeoff
graph display , ysize(4) xsize(9) scale(*1.3)