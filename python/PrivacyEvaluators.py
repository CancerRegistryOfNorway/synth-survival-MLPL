
import numpy as np
import settings

from sklearn.preprocessing import LabelEncoder, StandardScaler, OrdinalEncoder
from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from scipy import stats

import xgboost as xgb

from MyClasses import AttackEvaluation, MIAevaluate
import gower as gower
 
def AttackLeakage(real, synth, identifiers, sensitive, at_fpr, holdout):
    """  
    Evaluate the risk of an attribute inference attack. The attacker has access 
    to the synthetic data, as well as some information about the real data (identifiers).
    The attacker attempts to uncover the sensitive attribute of the real records
    by training a XGBoost prediction algorithm on the synthetic data. 
    
    Parameters
    ----------
    real : DataFrame
        Dataframe containing real samples 
    synth : DataFrame
        Dataframe containing synthetic samples 
    identifiers : list
        List of column names used to identify individuals.
    sensitive : list
        List of column name for sensitive attribute.
    at_fpr : list
        List of set values of FPR to evaluate TPR
    holdout : list
        List of indicating which records in real are holodut records

    Returns
    -------
    evaluation : AttackEvaluation
        Object containing evaluation results.
    
    """

    evaluation = AttackEvaluation(synth = synth, 
                                  real = real.loc[holdout == 0,:], 
                                  holdout = real.loc[holdout == 1,:], 
                                  identifiers = identifiers, 
                                  outcome = sensitive, 
                                  at_fpr = at_fpr)
    
    label_encoder = LabelEncoder()

    evaluation.y_synth = label_encoder.fit_transform(evaluation.y_synth)
    evaluation.y_real = label_encoder.transform(evaluation.y_real)
    evaluation.y_holdout = label_encoder.transform(evaluation.y_holdout)

    if evaluation.classes > 2:
        params = {
            'objective': 'multi:softmax',
            'eval_metric': 'merror',
            'num_class': evaluation.classes
            }
    else:
        params = {
            'objective': 'binary:logistic',
            'eval_metric': 'error'
            }

    
    params.update({
            'subsample': 0.75,
            'min_child_weight': 3,
            'max_depth': 5,
            'learning_rate': 0.2,
            'lambda': 10,
            'gamma': 2,
            'colsample_bytree': 0.75
            })
            
    xgtrain = xgb.DMatrix(evaluation.X_synth, label=evaluation.y_synth)
    
    cvresults = xgb.cv(params, xgtrain, 
                        metrics = 'merror',
                        num_boost_round = 1000,
                        nfold = 10, early_stopping_rounds = 50,
                        seed=42)
    
    n_est = cvresults.shape[0]
    print("n_estimators: " + str(n_est))
    
    xgb_base = xgb.XGBClassifier(n_jobs = 2, n_estimators = n_est, **params)
    xgb_base.fit(evaluation.X_synth, evaluation.y_synth)
    
    evaluation.evaluate(xgb_base)
        
    return(evaluation)


def MIA_density(synth, real, variables, at_fpr, holdout, function = 'density', use_reference = False):
    """  
    Evaluate the risk of an attribute inference attack. The attacker has access 
    to the synthetic data, as well as some information about the real data (identifiers).
    The attacker attempts to uncover the sensitive attribute of the real records
    by training a XGBoost prediction algorithm on the synthetic data. 
    
    Parameters
    ----------
    real : DataFrame
        Dataframe containing real samples 
    synth : DataFrame
        Dataframe containing synthetic samples 
    variables : list
        List of variables to include in density estimation. 
    at_fpr : list
        List of set values of FPR to evaluate TPR
    holdout : list
        List of indicating which records in real are holodut records
    function : str
        Scoring function, 'density' or 'dcr'
    use_reference : Bool
        Indicates whether to include calibration using reference data.

    Returns
    -------
    evaluation : MIAevaluate
        Object containing evaluation results.
    
    """
    
    evaluation = MIAevaluate(at_fpr = at_fpr)
    
    if function == 'density' :
        real['score'] =  density(synth, real, variables)
    elif function == 'dcr' : 
        distances =  DCR(synth, real)
        real['score'] = -distances 
    
    real['member'] = 1-holdout
    
    evaluation.evaluate(member = real['member'], density = real['score'])
    
    if use_reference:
        reference = np.random.randint(0, 2, size = np.sum(holdout))
        real.loc[real['member'] == 0, ['reference']] = reference
        real.loc[real['member'] == 1, ['reference']] = 0
        
        reference = real.loc[real['reference'] == 1,:].copy()
        real = real.loc[real['reference'] == 0,:].copy()
        
        if function == 'density' :
            score_synth, score_ref = density_ref(synth = synth, 
                                         real = real, 
                                         reference = reference, 
                                         variables = variables)
            real['score'] = score_synth/score_ref
            
        elif function == 'dcr' : 
            distances_synth, distances_ref  =  DCR_ref(synth=synth, 
                                                       real = real, 
                                                       reference = reference
                                                       )
            
            real['score'] = distances_ref - distances_synth
        
        
        evaluation.evaluate_ref(member = real['member'], density = real['score'])
        
    return(evaluation)



def SBPM(synth, real):
    """

    Parameters
    ----------
    synth : DataFrame
        Dataframe containing synthetic samples
    real : DataFrame
        Dataframe containing real samples

    Returns
    -------
    ims : float64
       Identical match share (reproduction rate)
    dcr: float64
       Mean distance to closest record (synth to real)
    id_score : float64
        Identifiability score 

    """
    
    # DCR from synthetic to real
    distances_synth_to_real, _ = gower.calculate_nearest_neighbors_distances(real, settings.numeric, settings.categorical, 1, synth)
    
    dcr = np.mean(distances_synth_to_real)
    ims = np.mean(distances_synth_to_real == 0)
    
    # Identifiability score 
    distances_real_to_synth, _ = gower.calculate_nearest_neighbors_distances(synth, settings.numeric, settings.categorical, 1, real, scaling = synth)
    distances_real_to_real, _ = gower.calculate_nearest_neighbors_distances(real, settings.numeric, settings.categorical, 2, real, scaling = synth)
    
    distances_real_to_synth, _ = gower.calculate_nearest_neighbors_distances(data = synth, 
                                                               numeric_cols = settings.numeric, 
                                                               cat_cols = settings.categorical, 
                                                               samples = real,
                                                               num_neighbors = 1)

    distances_real_to_real, _ = gower.calculate_nearest_neighbors_distances(data = real, 
                                                               numeric_cols = settings.numeric, 
                                                               cat_cols = settings.categorical, 
                                                               samples = real,
                                                               num_neighbors = 2, 
                                                               scaling = synth)
    
    id_score = np.mean(distances_real_to_synth.reshape(-1) < distances_real_to_real[:,1])
    
    return(ims, dcr, id_score)
    

def density(synth, real, variables):
    """

    Parameters
    ----------
    synth : DataFrame
        Dataframe containing synthetic samples
    real : DataFrame
        Dataframe containing real samples
    variables : list
        List of variables to include in density estimation. 

    Returns
    -------
    density: Array of float64
        Density of real records in synthetic data

    """
    numerical_transformer = StandardScaler()
    
    categorical_transformer = Pipeline([
            ('encoder', OrdinalEncoder(handle_unknown='use_encoded_value',unknown_value=9)),
            ('scaler', StandardScaler())
        ])
    
    full_transformer = ColumnTransformer([
            ('numerical', numerical_transformer, settings.numeric),
            ('categorical', categorical_transformer, settings.categorical)
        ], remainder='passthrough')
    
    full_transformer.fit(synth[variables])
    
    
    X_synth = full_transformer.transform(synth[variables])
    X_real = full_transformer.transform(real[variables])
    
    fit = stats.gaussian_kde(X_synth.T, bw_method="silverman")
    density = fit.evaluate(X_real.T)
    return(density)

def density_ref(synth, real, reference, variables):
    """

    Parameters
    ----------
    synth : DataFrame
        Dataframe containing synthetic samples
    real : DataFrame
        Dataframe containing real samples
    reference : DataFrame
        Dataframe containing reference samples
    variables : list
        List of variables to include in density estimation. 

    Returns
    -------
    density_synth: Array of float64
        Density of real records in synthetic data
    density_ref: Array of float64
        Density of real records in reference data

    """
    numerical_transformer = StandardScaler()
    
    categorical_transformer = Pipeline([
            ('encoder', OrdinalEncoder(handle_unknown='use_encoded_value',unknown_value=9)),
            ('scaler', StandardScaler())
        ])
    
    full_transformer = ColumnTransformer([
            ('numerical', numerical_transformer, settings.numeric),
            ('categorical', categorical_transformer, settings.categorical)
        ], remainder='passthrough')
    
    full_transformer.fit(synth[variables])
    
    
    X_synth = full_transformer.transform(synth[variables])
    X_real = full_transformer.transform(real[variables])
    X_ref = full_transformer.transform(reference[variables])
    
    fit_synth = stats.gaussian_kde(X_synth.T, bw_method="silverman")
    fit_ref = stats.gaussian_kde(X_ref.T, bw_method="silverman")
    
    density_synth = fit_synth.evaluate(X_real.T)
    density_ref = fit_ref.evaluate(X_real.T)
    return(density_synth, density_ref)
    

def DCR(synth, real):
    """
    Distance to closest synthetic sample from all real samples

    Parameters
    ----------
    synth : DataFrame
        Synthetic data.
    real : DataFrame
        Real data.

    Returns
    -------
    distances : Array 

    """
    distances, _ = gower.calculate_nearest_neighbors_distances(synth, settings.numeric, settings.categorical, 1, real)
    return(distances)

def DCR_ref(synth, real, reference):
    distances_synth, _ = gower.calculate_nearest_neighbors_distances(data = synth,
                                                                     numeric_cols = settings.numeric, 
                                                                     cat_cols = settings.categorical, 
                                                                     num_neighbors = 1, 
                                                                     samples = real)
    distances_ref, _ = gower.calculate_nearest_neighbors_distances(data = reference,
                                                                   numeric_cols = settings.numeric, 
                                                                   cat_cols = settings.categorical, 
                                                                   num_neighbors = 1, 
                                                                   samples = real)
    return(distances_synth, distances_ref)

