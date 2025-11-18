# -*- coding: utf-8 -*-

import pandas as pd
import numpy as np

from sklearn.preprocessing import OneHotEncoder
from sklearn.compose import ColumnTransformer

from scipy import stats

import settings

def load_sim_data(df_sim, df_orig):  
    df_sim['real'] = 0
    
    df_orig = df_orig.loc[:,list(df_sim.columns)]
    df_comb = pd.concat([df_orig, df_sim], axis = 0)
    df_comb = df_comb.drop(['id'], axis = 1)
    
    for v in ['diag_date', 'exit']:
        df_comb[v] = pd.to_datetime(df_comb[v], format='%d%b%Y')  
        df_comb[v+'_delta'] = (df_comb[v] - df_comb[v].min()) / np.timedelta64(1,'D')
        df_comb = df_comb.drop([v], axis = 1)
    
    return(df_comb)

def encode_data(df_comb):
    y = df_comb['real']
    
    num = [i for i in df_comb.columns if i in settings.numeric]
    cat = [i for i in df_comb.columns if i in settings.categorical]
    
    comb_vars = df_comb.loc[:, num + cat]
    
    encode_transformer = ColumnTransformer(
        [('encoder', OneHotEncoder(sparse_output = False), cat)],
        remainder = 'passthrough')
    
    X = encode_transformer.fit_transform(comb_vars)
    
    feat_names = encode_transformer.transformers_[0][1].get_feature_names_out().tolist() + num
    return(X, y, feat_names)


def empirical_epsilon(tpr, fpr, n_members, n_nonmembers):
    """
    For each possible treshold, it computes a lower bound for epsilon, using
    Clopper-Pearson confidence intervals to lower bound to TPR and
    upper bound the FPR.
    
    Parameters
    ----------
    tpr : Array 
        Array for TPRs
    fpr : Array
        Array for FPRs
    n_members : list
        Number of positive instances(members)
    n_nonmembers : list
        Number of negative instances(non-members)

    Returns
    -------
    epsilon_lb : float64
        Highest lower bound across all possible tresholds. 
    index : int
        Index for optimal treshold. 

    """
    
    epsilon_lb = 0
    index = np.nan
    
    for i in range(len(tpr)):
        if fpr[i] == 0:
            continue
        
        n_pos = int(tpr[i]*n_members)
        test_pos = stats.binomtest(n_pos, n_members)
        ci_pos = np.array(test_pos.proportion_ci())
        
        n_neg = int(fpr[i]*n_nonmembers)
        test_neg = stats.binomtest(n_neg, n_nonmembers)
        ci_neg = np.array(test_neg.proportion_ci())
        
        if ci_pos[0] == 0:
            continue
        
        epsilon_new = np.log(ci_pos[0]/ci_neg[1])
        if epsilon_new > epsilon_lb :
            epsilon_lb = epsilon_new
            index = i 
        
    return(epsilon_lb, index)


krgcolors = {
    "darkblue" : "#02406B",
    "lightblue" : "#139CFB",
    "red" : "#BC1C3B",
    "green" : "#4AA1A0",
    "yellow" : "#E3AB24"
    }