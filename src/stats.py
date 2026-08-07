import pandas as pd
from scipy import stats

def compare_top_bottom(us: pd.DataFrame, metric_col: str, metrics: list, q_high=0.8, q_low=0.2) -> pd.DataFrame:
    q_top = us[metric_col].quantile(q_high)
    q_bot = us[metric_col].quantile(q_low)
    top = us[us[metric_col] >= q_top]
    bottom = us[us[metric_col] <= q_bot]

    rows = []
    for m in metrics:
        t_top = top[m].dropna()
        t_bot = bottom[m].dropna()
        if len(t_top) < 2 or len(t_bot) < 2:
            continue
        t, p = stats.ttest_ind(t_top, t_bot, equal_var=False)
        rows.append([m, t_top.mean(), t_bot.mean(), t, p, 'Y' if p < 0.05 else ''])

    return pd.DataFrame(rows, columns=['지표', '상위평균', '하위평균', 't', 'p', '유의(p<.05)'])