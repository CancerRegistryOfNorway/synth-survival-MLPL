# -*- coding: utf-8 -*-


import settings
import numpy as np
from sklearn import metrics
from utils import empirical_epsilon
from sklearn.preprocessing import LabelBinarizer
import PlotFunctions as pf


class Metric:
    def __init__(self, name):
        self.name = name
        self.values = np.full((settings.n_sim, len(settings.levels)), np.nan)
        
    def aggregate(self):
        self.means = self.values.mean(axis = 0)
        self.stds = self.values.std(axis = 0)
        self.ylim = [np.min(self.means - self.stds), 
                     np.max(self.means + self.stds)]
        
    def plot(self, ylim, save = False):
        pf.plot_metric(settings.level_names, self.means, self.stds, self.name, 
                       ylim, save)
        
    def plot_trade_off(self, other, save = False):
        pf.trade_off_plot(self.means, self.stds, other.means, other.stds, 
                       settings.level_names, self.name, other.name, save) 
    
    def box_plot(self, save = False):
        pf.plot_box_metric(self.values, settings.level_names, self.name, save)
        
   
class VarMetric:
    def __init__(self, name, varlist):
        self.name = name
        self.varlist = varlist
        self.values = np.full((len(settings.levels), len(varlist), settings.n_sim), np.nan)
    
    def aggregate(self):
        self.means_var = self.values.mean(axis = 2)
        self.means = self.values.mean(axis = 2).mean(axis = 1)
        self.stds = self.values.mean(axis = 1).std(axis = 1)
        self.ylim = [np.min(self.means - self.stds), 
                     np.max(self.means + self.stds)]
        
    def plot_by_var(self, labels = True, save = False):
        pf.plot_heat_metric(self.means_var, self.varlist, settings.level_names, 
                         self.name, labels = labels, save = save)

    def plot(self, ylim, save = False):
        pf.plot_metric(settings.level_names, self.means, self.stds, self.name,
                       ylim, save)
        
    def plot_trade_off(self, other, save = False):
        pf.trade_off_plot(self.means, self.stds, other.means, other.stds, 
                       settings.level_names, self.name, other.name, save)
        
    def box_plot(self, save = False):
        pf.plot_box_metric(self.values.mean(axis = 1).transpose(), 
                           settings.level_names, self.name, save)
        
class AttackEvaluation:
    def __init__(self, synth, real, holdout, identifiers, outcome, at_fpr):
        self.at_fpr = at_fpr
        self.outcome = outcome
        self.identifiers = identifiers
        
        self.X_real = real.loc[:,identifiers]
        self.X_synth = synth.loc[:,identifiers]
        self.X_holdout = holdout.loc[:,identifiers]
        
        self.y_real = real[outcome]
        self.y_synth = synth[outcome]
        self.y_holdout = holdout[outcome]
        
        self.classes = len(np.unique(self.y_synth))
        
    def evaluate(self, model):
        # real traning data
        pred_real = model.predict(self.X_real)
        pred_real_proba = model.predict_proba(self.X_real)

        label_binarizer = LabelBinarizer().fit(self.y_real)
        y_onehot_real = label_binarizer.transform(self.y_real)
        
        # real holdout data:
        pred_holdout = model.predict(self.X_holdout)
        pred_hodlout_proba = model.predict_proba(self.X_holdout)

        y_onehot_holdout = label_binarizer.transform(self.y_holdout)

        self.tpr_at_fpr = np.full((len(self.at_fpr), self.classes), np.nan)
        self.auc = [np.nan] * self.classes
        
        self.tpr_at_fpr_holdout = np.full((len(self.at_fpr), self.classes), np.nan)
        self.auc_holdout = [np.nan] * self.classes
     
        for class_id in range(self.classes):
            
            fpr, tpr, _ = metrics.roc_curve(y_onehot_real[:,class_id], pred_real_proba[:,class_id])
            self.auc[class_id] = metrics.roc_auc_score(y_onehot_real[:,class_id], pred_real_proba[:,class_id])
            
            fpr_ref, tpr_ref, _ = metrics.roc_curve(y_onehot_holdout[:,class_id], pred_hodlout_proba[:,class_id])
            self.auc_holdout[class_id] = metrics.roc_auc_score(y_onehot_holdout[:,class_id], pred_hodlout_proba[:,class_id])
            
            for fpr_id in range(len(self.at_fpr)):
                
                self.tpr_at_fpr[fpr_id,class_id] = np.max(tpr[fpr <= self.at_fpr[fpr_id]])
                self.tpr_at_fpr_holdout[fpr_id,class_id] = np.max(tpr_ref[fpr_ref <= self.at_fpr[fpr_id]])
     
        self.accuracy = metrics.accuracy_score(self.y_real, pred_real)
        self.accuracy_holdout = metrics.accuracy_score(self.y_holdout, pred_holdout)
        
class MIAevaluate:
    def __init__(self, at_fpr):
        self.at_fpr = at_fpr
        
        
    def evaluate(self, member, density):
        fpr, tpr, tresholds =  metrics.roc_curve(member, density)
        
        self.auc = metrics.roc_auc_score(member, density)
        
        self.tpr_at_fpr = [np.nan] * len(self.at_fpr)
        
        for fpr_id in range(len(self.at_fpr)):
            self.tpr_at_fpr[fpr_id] = np.max(tpr[fpr <= self.at_fpr[fpr_id]])
            
        self.epsilon_lb, _ =  empirical_epsilon(tpr = tpr, 
                                                fpr = fpr, 
                                                n_members = sum(member), 
                                                n_nonmembers = sum(1-member))
        
    def evaluate_ref(self, member, density):
        fpr, tpr, tresholds =  metrics.roc_curve(member, density)
        
        self.auc_ref = metrics.roc_auc_score(member, density)
        
        self.tpr_at_fpr_ref = [np.nan] * len(self.at_fpr)
        
        for fpr_id in range(len(self.at_fpr)):
            self.tpr_at_fpr_ref[fpr_id] = np.max(tpr[fpr <= self.at_fpr[fpr_id]])
            
        self.epsilon_lb_ref, _ = empirical_epsilon(tpr = tpr, 
                                                    fpr = fpr, 
                                                    n_members = sum(member), 
                                                    n_nonmembers = sum(1-member))
                

        
class EvaluationResults:
    def __init__(self, site):
        self.site = site
        self.results = []
        self.result_names = []
    
    def log_result(self, result):
        self.results.append(result)
        self.result_names.append(result.name)
