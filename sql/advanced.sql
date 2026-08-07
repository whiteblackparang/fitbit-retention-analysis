
SET sql_mode='ANSI_QUOTES';

-- 01.사용자별 걸음수 기준 날짜 순위
SELECT 
    "Id", "ActivityDate", "TotalSteps",
    ROW_NUMBER() OVER (PARTITION BY "Id" ORDER BY "TotalSteps" DESC) AS steps_rank
FROM daily_features
WHERE is_worn = TRUE;

-- 02.동점 처리 방식 비교
SELECT
    "Id", "ActivityDate", "TotalSteps",
    RANK()       OVER (PARTITION BY "Id" ORDER BY "TotalSteps" DESC) AS rnk,
    DENSE_RANK() OVER (PARTITION BY "Id" ORDER BY "TotalSteps" DESC) AS dense_rnk
FROM daily_features
WHERE is_worn = TRUE;

-- 03.전날 대비 걸음수 변화량
SELECT
    "Id", "ActivityDate", "TotalSteps",
    "TotalSteps" - LAG("TotalSteps") OVER (PARTITION BY "Id" ORDER BY "ActivityDate") AS steps_change
FROM daily_features
WHERE is_worn = TRUE;

-- 04.다음날 걸음수 미리보기 (감소 예측용)
SELECT
    "Id", "ActivityDate", "TotalSteps",
    LEAD("TotalSteps") OVER (PARTITION BY "Id" ORDER BY "ActivityDate") AS next_day_steps
FROM daily_features
WHERE is_worn = TRUE;

-- 05.이동평균(7일): 활동량 추세 파악 (Q2: 감소 시점 탐지)
SELECT
    "Id", "ActivityDate", "TotalSteps",
    ROUND(AVG("TotalSteps") OVER (
        PARTITION BY "Id" ORDER BY "ActivityDate"
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 1) AS steps_7day_ma
FROM daily_features
WHERE is_worn = TRUE;

-- 06.사용자별 누적 걸음수
SELECT
    "Id", "ActivityDate", "TotalSteps",
    SUM("TotalSteps") OVER (PARTITION BY "Id" ORDER BY "ActivityDate") AS cumulative_steps
FROM daily_features
WHERE is_worn = TRUE;

-- 07.사용자×주말여부별 순위
SELECT
    "Id", is_weekend, "ActivityDate", "TotalSteps",
    RANK() OVER (PARTITION BY "Id", is_weekend ORDER BY "TotalSteps" DESC) AS rnk_within_group
FROM daily_features
WHERE is_worn = TRUE;

-- 08.리텐션 코호트: 관찰 시작일 기준 경과일수별 착용 유지율
-- PostgreSQL: (d."ActivityDate" - f.start_date) AS day_offset
-- SQL Server: DATEDIFF(day, f.start_date, d."ActivityDate")
WITH first_day AS (
    SELECT "Id", MIN("ActivityDate") AS start_date
    FROM daily_features GROUP BY "Id"
),
days_since_start AS (
    SELECT d."Id", DATEDIFF(d."ActivityDate", f.start_date) AS day_offset, d.is_worn   -- MySQL
    FROM daily_features d
    JOIN first_day f ON d."Id" = f."Id"
)
SELECT
    day_offset,
    COUNT(*) AS total_users,
    SUM(CASE WHEN is_worn THEN 1 ELSE 0 END) AS worn_users,
    ROUND(SUM(CASE WHEN is_worn THEN 1 ELSE 0 END) / COUNT(*), 3) AS retention_rate   -- ::FLOAT 제거
FROM days_since_start
GROUP BY day_offset
ORDER BY day_offset;

-- 09.걸음수 중앙값/사분위수
-- PostgreSQL: PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY "TotalSteps")
-- MySQL엔 PERCENTILE_CONT 없음 -> PERCENT_RANK()로 대체 계산
WITH ranked AS (
    SELECT "TotalSteps",
           PERCENT_RANK() OVER (ORDER BY "TotalSteps") AS pr
    FROM daily_features
    WHERE is_worn = TRUE
)
SELECT
    MIN(CASE WHEN pr >= 0.25 THEN "TotalSteps" END) AS q1,
    MIN(CASE WHEN pr >= 0.50 THEN "TotalSteps" END) AS median,
    MIN(CASE WHEN pr >= 0.75 THEN "TotalSteps" END) AS q3
FROM ranked;

-- 10.요일별 컬럼으로 평균 걸음수 펼치기
SELECT
    "Id",
    ROUND(AVG(CASE WHEN weekday = 'Monday'    THEN "TotalSteps" END), 1) AS mon,
    ROUND(AVG(CASE WHEN weekday = 'Tuesday'   THEN "TotalSteps" END), 1) AS tue,
    ROUND(AVG(CASE WHEN weekday = 'Wednesday' THEN "TotalSteps" END), 1) AS wed,
    ROUND(AVG(CASE WHEN weekday = 'Thursday'  THEN "TotalSteps" END), 1) AS thu,
    ROUND(AVG(CASE WHEN weekday = 'Friday'    THEN "TotalSteps" END), 1) AS fri,
    ROUND(AVG(CASE WHEN weekday = 'Saturday'  THEN "TotalSteps" END), 1) AS sat,
    ROUND(AVG(CASE WHEN weekday = 'Sunday'    THEN "TotalSteps" END), 1) AS sun
FROM daily_features
WHERE is_worn = TRUE
GROUP BY "Id";

-- 11.전체 관찰기간 날짜 시리즈 생성 (결측일 파악용)
-- PostgreSQL: d + INTERVAL '1 day'
WITH RECURSIVE date_series AS (
    SELECT MIN("ActivityDate") AS d FROM daily_features
    UNION ALL
    SELECT d + INTERVAL 1 DAY FROM date_series   -- MySQL: 따옴표 없이
    WHERE d + INTERVAL 1 DAY <= (SELECT MAX("ActivityDate") FROM daily_features)
)
SELECT d AS calendar_date FROM date_series;

-- 12.클러스터별 요약 뷰(VIEW 생성)
CREATE OR REPLACE VIEW cluster_profile AS
SELECT
    "Persona",
    COUNT(*) AS n_users,
    ROUND(AVG("AvgSteps"), 1) AS avg_steps,
    ROUND(AVG("AvgActiveMinutes"), 1) AS avg_active_minutes,
    ROUND(AVG("WearRate"), 3) AS avg_wear_rate
FROM user_summary_clustered
GROUP BY "Persona"
ORDER BY avg_steps;

-- 13.위에서 만든 뷰 조회
SELECT * FROM cluster_profile;

-- 14.조회 성능 개선 (Id+날짜 복합 인덱스)
CREATE INDEX idx_daily_features_id_date
ON daily_features ("Id", "ActivityDate");

-- 15.걸음수-칼로리 상관계수
-- PostgreSQL: ROUND(CORR("TotalSteps", "Calories")::NUMERIC, 3)
-- MySQL엔 CORR() 없음 -> 수동 공식
SELECT
    (COUNT(*) * SUM("TotalSteps" * "Calories") - SUM("TotalSteps") * SUM("Calories"))
    /
    (SQRT(COUNT(*) * SUM(POW("TotalSteps",2)) - POW(SUM("TotalSteps"),2))
     * SQRT(COUNT(*) * SUM(POW("Calories",2)) - POW(SUM("Calories"),2)))
    AS corr_steps_calories
FROM daily_features
WHERE is_worn = TRUE;

-- 16.사용자별 걸음수 변동성
-- PostgreSQL: STDDEV(...)::NUMERIC, VARIANCE(...)::NUMERIC
SELECT
    "Id",
    ROUND(STDDEV("TotalSteps"), 1) AS steps_stddev,     -- MySQL: 캐스팅 불필요
    ROUND(VARIANCE("TotalSteps"), 1) AS steps_variance
FROM daily_features
WHERE is_worn = TRUE
GROUP BY "Id"
ORDER BY steps_stddev DESC;

-- 17.사용자별 첫날, 마지막날 걸음수
SELECT DISTINCT
    "Id",
    FIRST_VALUE("TotalSteps") OVER (PARTITION BY "Id" ORDER BY "ActivityDate") AS first_day_steps,
    LAST_VALUE("TotalSteps") OVER (
        PARTITION BY "Id" ORDER BY "ActivityDate"
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_day_steps
FROM daily_features
WHERE is_worn = TRUE;

-- 18.미착용 공백(gap) 탐지: 연속 미착용일 구간 찾기 (아일랜드/갭 기법)
-- PostgreSQL: "ActivityDate" - (ROW_NUMBER() OVER (...))::INT * INTERVAL '1 day'
WITH flagged AS (
    SELECT
        "Id", "ActivityDate", is_worn,
        "ActivityDate" - INTERVAL (ROW_NUMBER() OVER (PARTITION BY "Id", is_worn ORDER BY "ActivityDate")) DAY AS grp   -- MySQL
    FROM daily_features
)
SELECT "Id", MIN("ActivityDate") AS gap_start, MAX("ActivityDate") AS gap_end, COUNT(*) AS gap_length
FROM flagged
WHERE is_worn = FALSE
GROUP BY "Id", grp
HAVING COUNT(*) >= 2
ORDER BY gap_length DESC;

-- 19.페르소나별 걸음수 순위
SELECT
    "Id", "Persona", "AvgSteps",
    RANK() OVER (PARTITION BY "Persona" ORDER BY "AvgSteps" DESC) AS rank_in_persona
FROM user_summary_clustered
ORDER BY "Persona", rank_in_persona;

-- 20.사용자별 걸음수-수면 상관계수 (표본 5일 이상인 사용자만)
-- PostgreSQL: ROUND(CORR("TotalSteps", "TotalMinutesAsleep")::NUMERIC, 3)
SELECT
    "Id",
    COUNT(*) AS n_days,
    (COUNT(*) * SUM("TotalSteps" * "TotalMinutesAsleep") - SUM("TotalSteps") * SUM("TotalMinutesAsleep"))
    /
    (SQRT(COUNT(*) * SUM(POW("TotalSteps",2)) - POW(SUM("TotalSteps"),2))
     * SQRT(COUNT(*) * SUM(POW("TotalMinutesAsleep",2)) - POW(SUM("TotalMinutesAsleep"),2)))
    AS corr_steps_sleep
FROM daily_features
WHERE is_worn = TRUE AND "TotalMinutesAsleep" IS NOT NULL
GROUP BY "Id"
HAVING COUNT(*) >= 5
ORDER BY corr_steps_sleep;