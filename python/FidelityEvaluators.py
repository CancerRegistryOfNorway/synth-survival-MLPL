# -*- coding: utf-8 -*-

from sklearn import metrics
from sklearn.model_selection import train_test_split

import xgboost as xgb

def discriminate(X, y):
    """
    Train an xgboost.XGBClassifier to discriminate between real and synthetic
    data, and return the resulting false positive rate (fpr), true positive
    rate (tpr) from the ROC-curve, the predicted probabilities (y_prob) on the 
    training data, and the fitted model. 

    Parameters
    ----------
    X : Array of float64
        Array of feature columns
    y : Series
        Prediction target real = 0/1

    Returns
    -------
    fpr : Array of float64
    tpr : Array of float64
    y_prob : Array of float64
    xgb_base: sklearn.XGBClassifier 
    """
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size = 0.3)
    xgtrain = xgb.DMatrix(X_train, label=y_train)
    
    params = {'subsample': 0.75,
             'min_child_weight': 5,
             'max_depth': 3,
             'learning_rate': 0.2,
             'lambda': 10,
             'gamma': 2,
             'colsample_bytree': 0.75}
    cvresults = xgb.cv(params, xgtrain, 
                        metrics = 'auc',
                        num_boost_round = 1000,
                        nfold = 10, early_stopping_rounds = 50,
                        seed=42)
    
    n_est = cvresults.shape[0]
    print("n_estimators: " + str(n_est))

    xgb_base = xgb.XGBClassifier(objective = 'binary:logistic', eval_metric = 'logloss', 
                                  n_jobs = 4, **params, n_estimators = n_est)
    xgb_base.fit(X_train, y_train)
    
    y_prob = xgb_base.predict_proba(X_test)

    
    fpr, tpr, tresholds = metrics.roc_curve(y_test, y_prob[:,1])
    
    return(fpr, tpr, y_prob, xgb_base)

