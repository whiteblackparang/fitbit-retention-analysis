import pandas as pd
import os

def load_and_merge(dir1: str, dir2: str, filename: str, interim_dir: str):
    dfs = []
    for d, period in [(dir1, '1구간'), (dir2, '2구간')]:
        path = f'{d}/{filename}'
        if os.path.exists(path):
            df = pd.read_csv(path)
            df['ExportPeriod'] = period
            dfs.append(df)
    if not dfs:
        print(f'⚠ {filename} 없음')
        return None

    merged = pd.concat(dfs, ignore_index=True)

    date_col = next((c for c in ['ActivityDate','SleepDay','Date','ActivityHour','Time'] if c in merged.columns), None)
    if date_col:
        before = len(merged)
        merged = merged.drop_duplicates(subset=['Id', date_col])
        if before != len(merged):
            print(f'   ↳ {filename}: 중복 {before - len(merged)}건 제거')

    os.makedirs(interim_dir, exist_ok=True)
    merged.to_csv(f'{interim_dir}/{filename}', index=False)
    return merged


def load_daily_activity(interim_dir: str) -> pd.DataFrame:
    da = pd.read_csv(f'{interim_dir}/dailyActivity_merged.csv')
    da['ActivityDate'] = pd.to_datetime(da['ActivityDate'], format='%m/%d/%Y', errors='coerce')
    return da