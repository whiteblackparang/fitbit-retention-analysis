import pandas as pd
import numpy as np

def flag_unworn_days(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df['is_worn'] = ~((df['SedentaryMinutes'] >= 1440) | (df['Calories'] == 0))
    return df


def add_weekday_features(df: pd.DataFrame, date_col: str = 'ActivityDate') -> pd.DataFrame:
    df = df.copy()
    df['weekday'] = df[date_col].dt.day_name()
    df['is_weekend'] = df[date_col].dt.dayofweek >= 5
    return df


def dedupe_sleep(sleep: pd.DataFrame, date_col: str = 'SleepDay') -> pd.DataFrame:
    return sleep.drop_duplicates(subset=['Id', date_col])