
import numpy as np
import pandas as pd


def fast_sum_by_row(matrix):
    return np.matmul(matrix, np.ones(matrix.shape[1]))


# Distances samples to data
def calculate_nearest_neighbors_distances(data, cat_cols, numeric_cols, num_neighbors, samples, scaling = None):
    """

    Parameters
    ----------
    data : DataFrame
        Data to calculate distances to.
    cat_cols : List
        Categorical column names.
    numeric_cols : List
        Numerical column names.
    num_neighbors : int
        Number of neighbors to include.
    samples : DataFrame
        Data to calculate distances from.
    scaling : Bool, optional
        Data to be inlcuded to calculate the numerical ranges. The default is None.

    Returns
    -------
    distances: Array 
        Array of distances.
    indexes : Array
        Array of indexes of nearest neighbors.

    """
    num_data_rows = data.shape[0]
    num_indices_to_calc = samples.shape[0]
    
    if isinstance(scaling, pd.DataFrame):
        data = pd.concat([data, samples, scaling])
    else:
        data = pd.concat([data, samples])
    
    end_samples = num_data_rows + num_indices_to_calc
    
    cat_data = data[cat_cols]
    num_data = data[numeric_cols]
    num_features = len(cat_cols + numeric_cols)
    
    distances = np.zeros((num_indices_to_calc, num_neighbors)) 
    indexes = np.zeros((num_indices_to_calc, num_neighbors))
    
    cat_data = np.asarray(cat_data.apply(lambda x: pd.factorize(x)[0])) if not cat_data.empty else np.asarray(cat_data)
    
    # Range standardizing
    num_data = np.asarray(num_data.astype('float64'))
    numeric_ranges = np.max(num_data, axis = 0) - np.min(num_data, axis = 0)
    
    num_samples = num_data[num_data_rows:end_samples]
    cat_samples = cat_data[num_data_rows:end_samples]
    
    num_data = num_data[:num_data_rows]
    cat_data = cat_data[:num_data_rows]
    
    for i in range(num_indices_to_calc):  
        numeric_sample_i = num_samples[i, :]
        cat_sample_i = cat_samples[i, :]
        dist_to_sample_i = calculate_distances(
            categorical_sample=cat_sample_i, numeric_sample=numeric_sample_i, cat_data=cat_data,
            numeric_data=num_data, numeric_ranges=numeric_ranges, num_features=num_features
        )
        
        min_dist_indexes = np.argpartition(dist_to_sample_i, num_neighbors)[:num_neighbors]
        min_dist_indexes_ordered = sorted(min_dist_indexes, key=lambda x, arr=dist_to_sample_i: arr[x], reverse=False)
        indexes[i, :] = min_dist_indexes_ordered
        distances[i, :] = dist_to_sample_i[min_dist_indexes_ordered]

    return np.nan_to_num(distances, nan=np.nan, posinf=np.nan, neginf=np.nan), indexes
        
        

def calculate_distances(categorical_sample, numeric_sample, cat_data,
                        numeric_data, numeric_ranges, num_features):

    numeric_feat_dist_to_sample = numeric_data - numeric_sample
    np.abs(numeric_feat_dist_to_sample, out=numeric_feat_dist_to_sample)
   
    numeric_feat_dist_to_sample = numeric_feat_dist_to_sample.astype('float64')
    np.divide(numeric_feat_dist_to_sample, numeric_ranges, out=numeric_feat_dist_to_sample)

    cat_feature_dist_to_sample = (cat_data - categorical_sample) != 0

    dist_to_sample = fast_sum_by_row(cat_feature_dist_to_sample) + fast_sum_by_row(numeric_feat_dist_to_sample)

    return dist_to_sample / (num_features) 
