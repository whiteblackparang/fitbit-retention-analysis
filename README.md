# Fitbit 사용자 행동 분석을 통한 Activity Retention 개선 및 At-risk User 탐지

Fitbit 사용자의 활동·수면·심박·체중 데이터를 기반으로 운동 습관 형성 과정과 활동 수준 변화 패턴을 분석하고, 제품 개선 및 개인화 서비스 전략을 제안하는 프로젝트

> 행동 그룹 비교 → 상관 분석 → 사용자 군집화 → 시계열 리텐션 분석 → 제품 가설 도출까지 전 과정을 다룹니다.

---

## 문제 정의

헬스케어 제품 관점에서 핵심 질문

> **운동 습관은 언제, 어떻게 무너지기 시작하는가? 기기 착용과 실제 활동 유지는 같은 현상인가?**

## 데이터

- **출처**: Amazon Mechanical Turk 기반 Fitbit 사용자 데이터 (Furberg et al., 2016, Zenodo)
- **수집 기간**: 2016-03-12 ~ 2016-05-12
- **사용자 수**: 병합 후 35명 (분석별로 33 / 29 / 14 / 13명 등 표본 상이 — 표본 기준은 상세 리포트 참고)
- **주요 데이터**: `dailyActivity`, `sleepDay`, `weightLogInfo`, `heartrate_seconds`, `hourlySteps` 등 18종 CSV

## 사용 기술 스택

| 구분 | 사용 기술 |
|---|---|
| Language | Python |
| Database | MySQL |
| Analysis | pandas, numpy, scipy |
| Statistics | t-test, Pearson correlation |
| ML | K-Means clustering (scikit-learn) |
| Visualization | matplotlib, seaborn, networkx |

## 분석 과정

### 1. 행동 그룹 비교 (`notebooks/07_ttest.ipynb`)
`WearRate`(관찰기간 중 착용일 비율) 상위 20% vs 하위 20% 사용자의 행동 지표를 t-test로 비교

### 2. 상관 분석 (`notebooks/05_correlation.ipynb`, `12_weight_log_habit.ipynb`)
좌식비율·수면시간 관계, 체중기록 빈도·활동량 관계를 상관계수로 검증하고 이상치 영향을 전/후 비교

### 3. 사용자 군집화 (`notebooks/08_cluster.ipynb`, `09_persona.ipynb`)
K=2~6 실루엣 스코어 비교 후 K-Means로 행동 유형 분류

### 4. 시계열 리텐션 분석 (`notebooks/11_retention_trend.ipynb`)
사용자별 7일 이동평균 걸음수를 계산해 개인 baseline 대비 활동량 감소 시점 탐지

| 분석 | 검정/방법 | 결과 |
|---|---|---|
| WearRate 상·하위 행동 차이 | Welch's t-test | 활동시간·고강도활동 유의(p<0.05), 총칼로리는 유의차 없음 |
| 좌식비율 ↔ 수면시간 | Pearson 상관 | r = -0.60 |
| 체중기록 ↔ 활동량 | Pearson 상관 | 전체 13명 r=0.58 → 이상치 2명 제외 후 r=0.167 |
| 사용자 군집화 | K-Means | K=2 (Active 67% / Sedentary 33%) |

## 주요 발견

- **Device Engagement ≠ Activity Retention**: 활동량 감소 분석 대상 29명 중 14명(48%)이 관찰 7~9일차에 개인 baseline 대비 30% 이상 활동량 감소 — 기기 착용 유지율(0.8~1.0)은 안정적이었던 반면 실제 활동은 먼저 무너짐
- WearRate 상위 그룹은 활동시간·고강도 활동이 유의하게 높고 좌식비율은 낮았으나, 총 칼로리 소비량에는 유의한 차이 없음
- 좌식비율이 걸음수보다 수면시간과 더 강한 상관관계를 보임 (r=-0.60)
- 체중기록 빈도-활동량의 상관(r=0.58)은 이상치 2명에 의해 과대평가된 결과였음 (제외 후 r=0.167)
- 평일/주말 활동량 차이는 크지 않아 Weekend Warrior 패턴은 뚜렷하게 나타나지 않음

## 폴더 구조

```
fitbit-retention-analysis/
├── data/
│   ├── raw/
│   │   ├── 01/
│   │   └── 02/
│   ├── interim/
│   └── processed/
├── notebooks/
│   ├── 01_load_merge.ipynb
│   ├── 02_clean.ipynb
│   ├── 03_features.ipynb
│   ├── 04_eda.ipynb
│   ├── 05_correlation.ipynb
│   ├── 06_heartrate.ipynb
│   ├── 07_ttest.ipynb
│   ├── 08_cluster.ipynb
│   ├── 09_persona.ipynb
│   ├── 10_load_to_mysql.ipynb
│   ├── 11_retention_trend.ipynb
│   └── 12_weight_log_habit.ipynb
├── src/
│   ├── loading
│   ├── cleaning
│   ├── features
│   ├── statistics
│   └── clustering
├── sql/
│   ├── basic.sql
│   ├── intermediate.sql
│   └── advanced.sql
├── outputs/
│   └── figures/
├── reports/
│   └── report.md
├── requirements.txt
└── .gitignore
```

## 실행 방법

1. `pip install -r requirements.txt`
2. 원본 CSV를 `data/raw/01/`, `data/raw/02/`에 배치 (`.gitignore`로 저장소에는 미포함)
3. 노트북 순차 실행: `01_load_merge` → `02_clean` → `03_features` → `04_eda` → `05_correlation` → `06_heartrate` → `07_ttest` → `08_cluster` → `09_persona` → `10_load_to_mysql` → `11_retention_trend` → `12_weight_log_habit`
4. SQL 분석은 `10_load_to_mysql`로 MySQL 8.0 적재 후 `basic.sql` → `intermediate.sql` → `advanced.sql` 순으로 실행 (총 63개 쿼리)

## 상세 리포트

분석 설계 논리, 프로젝트 스토리라인, 제품 가설별 A/B Test 설계, 표본·관찰기간·인과관계 해석상의 한계 등 전체 내용은 [`reports/report.md`](reports/report.md)에서 확인할 수 있습니다.
