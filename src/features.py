
import pandas as pd
import numpy as np

def add_activity_ratios(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df['ActiveMinutes'] = df['VeryActiveMinutes'] + df['FairlyActiveMinutes'] + df['LightlyActiveMinutes']
    df['ActiveRatio'] = df['ActiveMinutes'] / 1440
    df['SedentaryRatio'] = df['SedentaryMinutes'] / 1440
    df['VeryActiveRatio'] = df['VeryActiveMinutes'] / df['ActiveMinutes'].replace(0, np.nan)
    return df


def build_user_summary(daily: pd.DataFrame, weight: pd.DataFrame, hr_ids: set) -> pd.DataFrame:
    worn = daily[daily['is_worn']]

    total_days = daily.groupby('Id')['ActivityDate'].nunique()
    worn_days = worn.groupby('Id')['ActivityDate'].nunique()

    user_summary = pd.DataFrame({'ObservedDays': total_days, 'WornDays': worn_days}).fillna(0)
    user_summary['WearRate'] = user_summary['WornDays'] / user_summary['ObservedDays']

    agg = worn.groupby('Id').agg(
        AvgSteps=('TotalSteps', 'mean'),
        AvgCalories=('Calories', 'mean'),
        AvgActiveMinutes=('ActiveMinutes', 'mean'),
        AvgSedentaryRatio=('SedentaryRatio', 'mean'),
        AvgVeryActiveMinutes=('VeryActiveMinutes', 'mean'),
        AvgSleepMinutes=('TotalMinutesAsleep', 'mean'),
        SleepRecordedDays=('TotalMinutesAsleep', lambda s: s.notna().sum()),
    )

    weekday_avg = worn[~worn['is_weekend']].groupby('Id')['TotalSteps'].mean().rename('AvgSteps_Weekday')
    weekend_avg = worn[worn['is_weekend']].groupby('Id')['TotalSteps'].mean().rename('AvgSteps_Weekend')

    user_summary = user_summary.join(agg).join(weekday_avg).join(weekend_avg)

    weight_freq = weight.groupby('Id').size().rename('WeightLogCount')
    user_summary = user_summary.join(weight_freq).fillna({'WeightLogCount': 0})

    user_summary['HasHeartRate'] = user_summary.index.isin(hr_ids)
    return user_summary.round(2)