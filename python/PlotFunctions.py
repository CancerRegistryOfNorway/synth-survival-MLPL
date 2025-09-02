# -*- coding: utf-8 -*-

import matplotlib.pyplot as plt
import seaborn as sn
import pandas as pd
import numpy as np
#from lifelines import KaplanMeierFitter
from utils import krgcolors

def trade_off_plot(xvec, xerr, yvec, yerr, 
                   labels, xlab, ylab, save = False,
                   colors = ['lightblue','darkblue','yellow']):
    
    plt.figure(figsize=(8,6))
    plt.rcParams['figure.dpi'] = 300
    plt.rcParams['font.size'] = 16
    plt.rcParams['font.family'] = ['Segoe UI','sans-serif']
    for i in range(len(xvec)):
        col = colors[i]
        plt.errorbar(xvec[i], yvec[i], 
                     xerr = xerr[i], yerr = yerr[i], 
                     label = labels[i], fmt='o', color = krgcolors[col],
                     markersize = 8, elinewidth=2)

    plt.xlabel(xlab)
    plt.ylabel(ylab)
    plt.grid()
    plt.legend()
    if save:
        plt.savefig('export/' + xlab + '_' + ylab + '_tradeoff.png'
                    , bbox_inches = 'tight')
    else: 
        plt.show()
    
def plot_metric(xvec, yvec, yerr, ylab, ylim, save = False):
    
    plt.figure(figsize=(7,7))
    plt.rcParams['figure.dpi'] = 300
    plt.rcParams['font.size'] = 20
    plt.rcParams['grid.color'] = '#DDDDDD'
    plt.errorbar(xvec,  yvec, yerr=yerr, 
                 fmt='o-', color = krgcolors['lightblue'])
    plt.grid(axis='y')
    plt.ylabel(ylab)
    if ylim == [0, 0]:
        ylim[0] = np.min(yvec - yerr)
        ylim[1] = np.max(yvec + yerr)
    plt.ylim(ylim)
    
    if save:
        plt.savefig('export/' + ylab + '_line.png', bbox_inches = 'tight')
    else: 
        plt.show()

def plot_box_metric(values, xlab, ylab, save = False):
    df = pd.DataFrame(values)
    df.columns = xlab
    df = pd.DataFrame(df.stack())
    df.reset_index(inplace = True)
    
    plt.figure(figsize=(8,5))
    plt.rcParams['figure.dpi'] = 300
    plt.rcParams['font.size'] = 16
    plt.rcParams['font.family'] = ['Segoe UI','sans-serif']
    sn.boxplot(x = 'level_1', y = 0, data = df,
               linewidth = 0.8)
    plt.xlabel(None)
    plt.ylabel(ylab)
    if save:
        plt.savefig('export/' + ylab + '_box.png', bbox_inches = 'tight')
    else: 
        plt.show()