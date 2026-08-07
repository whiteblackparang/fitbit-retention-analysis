import pandas as pd
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score

def find_best_k(X, k_range=range(2, 7), random_state=42):
    scaled = StandardScaler().fit_transform(X)
    scores = {}
    for k in k_range:
        km = KMeans(n_clusters=k, n_init=10, random_state=random_state)
        labels = km.fit_predict(scaled)
        scores[k] = silhouette_score(scaled, labels)
    best_k = max(scores, key=scores.get)
    return best_k, scores, scaled


def assign_persona(us: pd.DataFrame, cluster_col='Cluster', sort_col='AvgSteps') -> pd.DataFrame:
    us = us.copy()
    order = us.groupby(cluster_col)[sort_col].mean().sort_values().index.tolist()
    n = len(order)

    presets = {
        2: ['Sedentary User', 'Active User'],
        3: ['Sedentary User', 'Moderate Mover', 'High Intensity User'],
        4: ['Sedentary User', 'Light Active', 'Steady Mover', 'High Intensity User'],
    }
    names = presets.get(n, [f'Level {i+1} User' for i in range(n)])

    persona_map = dict(zip(order, names))
    us['Persona'] = us[cluster_col].map(persona_map)
    return us