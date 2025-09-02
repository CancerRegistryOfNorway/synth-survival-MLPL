# -*- coding: utf-8 -*-

import settings
import numpy as np
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