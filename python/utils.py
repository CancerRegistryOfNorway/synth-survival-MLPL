# -*- coding: utf-8 -*-

import pandas as pd
import numpy as np

from sklearn.preprocessing import OneHotEncoder
from sklearn.compose import ColumnTransformer

import settings

def load_sim_data(df_sim, df_orig):  
    df_sim['real'] = 0
    
    df_orig = df_orig.loc[:,df_sim.columns]
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

krgcolors = {
    "darkblue" : "#02406B",
    "lightblue" : "#139CFB",
    "red" : "#BC1C3B",
    "green" : "#4AA1A0",
    "yellow" : "#E3AB24"
    }