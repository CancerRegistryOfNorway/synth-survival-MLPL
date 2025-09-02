# -*- coding: utf-8 -*-

import pandas as pd
import numpy as np
from sklearn import metrics

# self-defined functions
from utils import load_sim_data, encode_data
import FidelityEvaluators as fidelity
from MyClasses import Metric

###############################################################################
## CALCULATE METRICS

import settings
settings.categorical = ['stage']
settings.numeric = ['exit_delta','age','sex','_t','daar','status']

settings.identifiers = ['daar','age','status','exit_delta','sex','_t']
settings.sensitive = ['stage']
settings.n_sim = 50
settings.levels = ['margins', 'main', 'inter_agestage', 
                   'inter_agestagesex','inter_agestagesex3w',
                   'inter_agestagesex3w_df8','dummy' ]
settings.level_names = ['Indep. marginals', 'Model 1', 'Model 2', 'Model 3', 'Model 4', 
                        'Model 5', 'Resampling']


for site in ['colon','pancreas']:
    settings.site = site
    
    disc_auc = Metric('Discriminator AUC')
    prop_score = Metric('Propensity score')
    
    metric_list = [disc_auc, prop_score]

    df_orig = pd.read_csv('input/'+settings.site+'_original.csv')
    df_orig.loc[df_orig['stage'] == 999,'stage'] = 9
    df_orig['real'] = 1


    for i in range(1,settings.n_sim+1):
        for l in range(len(settings.levels)):
            print(str(l)+ ";"+ str(i))
            lvl = settings.levels[l]
            dataset = 'input/simulated_' + settings.site + '_' + lvl + str(i) + '.csv'
            
            df_synth = pd.read_csv(dataset)
            
            df_synth.loc[pd.isna(df_synth['stage']),'stage'] = 9
            df_synth.loc[df_synth['stage'] == 999,'stage'] = 9
            
            df_synth['diag_date'] = pd.to_datetime(df_synth['diag_date'],format='%d%b%Y')
            df_synth['daar'] = df_synth['diag_date'].dt.year
        
            df_comb = load_sim_data(df_synth, df_orig)
            
            X, y, feat_names = encode_data(df_comb)
            fpr, tpr, y_prob, xgb_base = fidelity.discriminate(X, y)
            
            auc = metrics.auc(fpr, tpr)
            disc_auc.values[i-1,l] = auc
            print("AUC: " + str(auc))
            
            propensity_score = np.sum(np.square(y_prob[:,1] - 0.5))/len(y_prob)
            
            prop_score.values[i-1,l] = propensity_score
            print("Prop. score: " + str(propensity_score))
        
    

    for m in metric_list:
        m.aggregate()
        m.plot(ylim = m.ylim)
        print(m.means)
    
    np.savetxt('export/' + settings.site + '_propensity_score.csv', prop_score.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_disc_auc.csv', disc_auc.values, delimiter=";")
    