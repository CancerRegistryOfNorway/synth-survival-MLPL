
import pandas as pd
import numpy as np
from sklearn import metrics

# self-defined functions
from utils import load_sim_data, encode_data
import FidelityEvaluators as fidelity
import PrivacyEvaluators as privacy
from MyClasses import Metric, VarMetric, EvaluationResults

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

###############################################################################
## CALCULATE METRICS W/O HOLDOUT DATA (SBPMS AND UTILITY METRICS)


for site in ['pancreas','colon']:
    
    evaluation_results = EvaluationResults(site)
    settings.site = site
    
    disc_auc = Metric('Discriminator AUC')
    prop_score = Metric('Propensity score')
    IMS = Metric('IMS')
    DCR = Metric('DCR')
    identity_score = Metric('Identifiability Score')


    metric_list = [disc_auc, prop_score, IMS, DCR, identity_score]
    
    df = pd.read_csv('input/'+settings.site+'_original.csv')
    
    df.loc[df['stage'] == 999,'stage'] = 9
    df['real'] = 1

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
        
            df_comb = load_sim_data(df_synth, df)
            
            X, y, feat_names = encode_data(df_comb)
            fpr, tpr, y_prob, xgb_base = fidelity.discriminate(X, y)
            
            auc = metrics.auc(fpr, tpr)
            disc_auc.values[i-1,l] = auc
            print("AUC: " + str(auc))
            
            propensity_score = np.sum(np.square(y_prob[:,1] - 0.5))/len(y_prob)
            
            prop_score.values[i-1,l] = propensity_score
            print("Prop. score: " + str(propensity_score))

            ims, dcr, id_score = privacy.SBPM(synth = df_comb.loc[df_comb['real'] == 0,:].copy(),
                                              real = df_comb.loc[df_comb['real'] == 1,:].copy())
            
            IMS.values[i-1,l] = ims
            DCR.values[i-1,l] = dcr
            identity_score.values[i-1,l] = id_score
    

    for m in metric_list:
        m.aggregate()
        m.plot(ylim = m.ylim)
        print(m.means)
    
    np.savetxt('export/' + settings.site + '_propensity_score.csv', prop_score.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_disc_auc.csv', disc_auc.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_ims.csv', IMS.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_dcr.csv', DCR.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_id_score.csv', identity_score.values, delimiter=";")


###############################################################################
## CALCULATE METRICS WITH HOLDOUT DATA (INFERENCE ATTACKS)

for site in ['pancreas','colon']:
    
    evaluation_results = EvaluationResults(site)
    settings.site = site
    
    inf_attack = Metric('Attribute Disclosure Accuracy')
    inf_attack_rel = Metric('Relative Attribute Disclosure Accuracy')
    inf_attack_fpr1 = VarMetric('Inference TPR@FPR=0', ['1','2','3','9'])
    inf_attack_fpr2 = VarMetric('Inference TPR@FPR=0.001', ['1','2','3','9'])
    inf_attack_fpr3 = VarMetric('Inference TPR@FPR=0.01', ['1','2','3','9'])
    inf_attack_auc = VarMetric('Inference ROc-AUC', ['1','2','3','9'])
    inf_attack_fpr1_holdout = VarMetric('Inference holdout TPR@FPR=0', ['1','2','3','9'])
    inf_attack_fpr2_holdout = VarMetric('Inference holdout TPR@FPR=0.001', ['1','2','3','9'])
    inf_attack_fpr3_holdout = VarMetric('Inference holdout TPR@FPR=0.01', ['1','2','3','9'])
    
    mia_density_fpr1 = Metric('MIA TPR@FPR=0')
    mia_density_fpr2 = Metric('MIA TPR@FPR=0.001')
    mia_density_fpr3 = Metric('MIA TPR@FPR=0.01')
    mia_density_auc = Metric('MIA ROC-AUC')
    mia_density_epsilon = Metric('MIA epsilon')
    
    mia_ref_density_fpr1 = Metric('MIA reference TPR@FPR=0')
    mia_ref_density_fpr2 = Metric('MIA reference TPR@FPR=0.001')
    mia_ref_density_fpr3 = Metric('MIA reference TPR@FPR=0.01')
    mia_ref_density_auc = Metric('MIA reference ROC-AUC')
    mia_ref_density_epsilon = Metric('MIA reference epsilon')
    
    mia_dcr_fpr1 = Metric('MIA dcr TPR@FPR=0')
    mia_dcr_fpr2 = Metric('MIA dcr TPR@FPR=0.001')
    mia_dcr_fpr3 = Metric('MIA dcr TPR@FPR=0.01')
    mia_dcr_auc = Metric('MIA dcr ROC-AUC')
    mia_dcr_epsilon = Metric('MIA epsilon')
    
    mia_dcr_diff_fpr1 = Metric('MIA dcr-diff TPR@FPR=0')
    mia_dcr_diff_fpr2 = Metric('MIA dcr-diff TPR@FPR=0.001')
    mia_dcr_diff_fpr3 = Metric('MIA dcr-diff TPR@FPR=0.01')
    mia_dcr_diff_auc = Metric('MIA dcr-diff ROC-AUC')
    mia_dcr_diff_epsilon = Metric('MIA dcr-diff epsilon')
    
    metric_list = [mia_density_fpr1, mia_density_fpr2, mia_density_fpr3, mia_density_auc, mia_density_epsilon,
                   mia_ref_density_fpr1, mia_ref_density_fpr2, mia_ref_density_fpr3, mia_ref_density_auc, mia_ref_density_epsilon,
                   mia_dcr_fpr1, mia_dcr_fpr2, mia_dcr_fpr3, mia_dcr_auc, mia_dcr_epsilon,
                   mia_dcr_diff_fpr1, mia_dcr_diff_fpr2, mia_dcr_diff_fpr3, mia_dcr_diff_auc, mia_dcr_diff_epsilon,
                   inf_attack_rel, inf_attack, inf_attack_fpr1, inf_attack_fpr2, inf_attack_fpr3, inf_attack_auc,
                   inf_attack_fpr1_holdout, inf_attack_fpr2_holdout, inf_attack_fpr3_holdout]

    for i in range(1,settings.n_sim+1):
        
        df = pd.read_csv('input/original_holdout_'+settings.site+'_'+ str(i)+'.csv')
        
        df.loc[df['stage'] == 999,'stage'] = 9
        df['real'] = 1
        
        for l in range(len(settings.levels)):

            print(str(l)+ ";"+ str(i))
            
            lvl = settings.levels[l]
            dataset = 'input/simulated_holdout_' + settings.site + '_' + lvl + str(i) + '.csv'
            
            df_synth = pd.read_csv(dataset)
            
            df_synth.loc[pd.isna(df_synth['stage']),'stage'] = 9
            df_synth.loc[df_synth['stage'] == 999,'stage'] = 9
            
            df_synth['diag_date'] = pd.to_datetime(df_synth['diag_date'],format='%d%b%Y')
            df_synth['daar'] = df_synth['diag_date'].dt.year
        
            df_comb = load_sim_data(df_synth, df)

            attack = privacy.AttackLeakage(real = df_comb.loc[df_comb['real'] == 1,:],
                                            synth = df_comb.loc[df_comb['real'] == 0,:], 
                                            identifiers = settings.identifiers, 
                                            sensitive = settings.sensitive[0], 
                                            at_fpr = [0,0.001,0.01],
                                            holdout = df['holdout'])
            
            inf_attack.values[i-1,l] = attack.accuracy
            inf_attack_rel.values[i-1,l] = (attack.accuracy-attack.accuracy_holdout)/(1-attack.accuracy_holdout)
            print("Accuracy: " + str(attack.accuracy))
            print("Accuracy (reference): " + str(attack.accuracy_holdout))
            
            inf_attack_fpr1.values[l,:,i-1] = attack.tpr_at_fpr[0,:]
            inf_attack_fpr2.values[l,:,i-1] = attack.tpr_at_fpr[1,:]
            inf_attack_fpr3.values[l,:,i-1] = attack.tpr_at_fpr[2,:]
            inf_attack_auc.values[l,:,i-1] = attack.auc
            
            inf_attack_fpr1_holdout.values[l,:,i-1] = attack.tpr_at_fpr_holdout[0,:]
            inf_attack_fpr2_holdout.values[l,:,i-1] = attack.tpr_at_fpr_holdout[1,:]
            inf_attack_fpr3_holdout.values[l,:,i-1] = attack.tpr_at_fpr_holdout[2,:]
            
            variables = settings.identifiers + settings.sensitive
            mia_evaluation = privacy.MIA_density(real = df_comb.loc[df_comb['real'] == 1,:].copy(),
                                                  synth = df_comb.loc[df_comb['real'] == 0,:].copy(), 
                                                  variables = variables,
                                                  at_fpr = [0,0.001,0.01],
                                                  holdout = df['holdout'],
                                                  use_reference = True)
            
            mia_density_fpr1.values[i-1,l] = mia_evaluation.tpr_at_fpr[0]
            mia_density_fpr2.values[i-1,l] = mia_evaluation.tpr_at_fpr[1]
            mia_density_fpr3.values[i-1,l] = mia_evaluation.tpr_at_fpr[2]
            mia_density_auc.values[i-1,l] = mia_evaluation.auc
            mia_density_epsilon.values[i-1,l] = mia_evaluation.epsilon_lb
            print("Epsilon_lb: " + str(mia_evaluation.epsilon_lb))
            
            
            mia_ref_density_fpr1.values[i-1,l] = mia_evaluation.tpr_at_fpr_ref[0]
            mia_ref_density_fpr2.values[i-1,l] = mia_evaluation.tpr_at_fpr_ref[1]
            mia_ref_density_fpr3.values[i-1,l] = mia_evaluation.tpr_at_fpr_ref[2]
            mia_ref_density_auc.values[i-1,l] = mia_evaluation.auc_ref
            mia_ref_density_epsilon.values[i-1,l] = mia_evaluation.epsilon_lb_ref
            print("Epsilon_lb (ref.): " + str(mia_evaluation.epsilon_lb_ref))
            
            variables = settings.identifiers + settings.sensitive
            mia_evaluation = privacy.MIA_density(real = df_comb.loc[df_comb['real'] == 1,:].copy(),
                                                 synth = df_comb.loc[df_comb['real'] == 0,:].copy(), 
                                                 variables = variables,
                                                 at_fpr = [0,0.001,0.01],
                                                 holdout = df['holdout'].copy(),
                                                 function = 'dcr', 
                                                 use_reference = True)
          
            mia_dcr_fpr1.values[i-1,l] = mia_evaluation.tpr_at_fpr[0]
            mia_dcr_fpr2.values[i-1,l] = mia_evaluation.tpr_at_fpr[1]
            mia_dcr_fpr3.values[i-1,l] = mia_evaluation.tpr_at_fpr[2]
            mia_dcr_auc.values[i-1,l] = mia_evaluation.auc
            mia_dcr_epsilon.values[i-1,l] = mia_evaluation.epsilon_lb
            print("Epsilon_lb: " + str(mia_evaluation.epsilon_lb))
            
            
            mia_dcr_diff_fpr1.values[i-1,l] = mia_evaluation.tpr_at_fpr_ref[0]
            mia_dcr_diff_fpr2.values[i-1,l] = mia_evaluation.tpr_at_fpr_ref[1]
            mia_dcr_diff_fpr3.values[i-1,l] = mia_evaluation.tpr_at_fpr_ref[2]
            mia_dcr_diff_auc.values[i-1,l] = mia_evaluation.auc_ref
            mia_dcr_diff_epsilon.values[i-1,l] = mia_evaluation.epsilon_lb_ref
            print("Epsilon_lb (ref.): " + str(mia_evaluation.epsilon_lb_ref))
    

    for m in metric_list:
        m.aggregate()
        m.plot(ylim = m.ylim)
        print(m.means)
        
        evaluation_results.log_result(m)
        
    if (site == 'colon'):
        colon = evaluation_results
    elif (site == 'pancreas'):
        pancreas = evaluation_results
        
    
    out = np.concatenate((np.tile([1,2,3,9],settings.n_sim)[:,None],inf_attack_fpr3.values.T.reshape(-1,inf_attack_fpr3.values.shape[0])),axis=1)
    np.savetxt('export/' + settings.site + '_inf_attack_fpr.csv', out, delimiter=";")
    
    out = np.concatenate((np.tile([1,2,3,9],settings.n_sim)[:,None],inf_attack_fpr3_holdout.values.T.reshape(-1,inf_attack_fpr3_holdout.values.shape[0])),axis=1)
    np.savetxt('export/' + settings.site + '_inf_attack_fpr_holdout.csv', out, delimiter=";")
    
    
    np.savetxt('export/' + settings.site + '_mia_dcr_diff_epsilon.csv', mia_dcr_diff_epsilon.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_mia_dcr_diff_fpr1.csv', mia_dcr_diff_fpr1.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_mia_dcr_diff_fpr2.csv', mia_dcr_diff_fpr2.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_mia_dcr_diff_fpr3.csv', mia_dcr_diff_fpr3.values, delimiter=";")
    
    np.savetxt('export/' + settings.site + '_mia_ref_density_epsilon.csv', mia_ref_density_epsilon.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_mia_ref_density_fpr1.csv', mia_ref_density_fpr1.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_mia_ref_density_fpr2.csv', mia_ref_density_fpr2.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_mia_ref_density_fpr3.csv', mia_ref_density_fpr3.values, delimiter=";")
    
    np.savetxt('export/' + settings.site + '_mia_dcr_epsilon.csv', mia_dcr_epsilon.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_mia_dcr_fpr1.csv', mia_dcr_fpr1.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_mia_dcr_fpr2.csv', mia_dcr_fpr2.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_mia_dcr_fpr3.csv', mia_dcr_fpr3.values, delimiter=";")
    
    np.savetxt('export/' + settings.site + '_mia_density_epsilon.csv', mia_density_epsilon.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_mia_density_fpr1.csv', mia_density_fpr1.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_mia_density_fpr2.csv', mia_density_fpr2.values, delimiter=";")
    np.savetxt('export/' + settings.site + '_mia_density_fpr3.csv', mia_density_fpr3.values, delimiter=";")
