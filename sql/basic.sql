USE fitbit_retention;
SET sql_mode='ANSI_QUOTES';

-- 01. 전체 컬럼 조회
SELECT * FROM daily_features LIMIT 20;

-- 02. 특정 컬럼만 조회
SELECT "Id", "ActivityDate", "TotalSteps", "Calories"
FROM daily_features;

-- 03.만보 이상인 날
SELECT "Id", "ActivityDate", "TotalSteps"
FROM daily_features
WHERE "TotalSteps" >= 10000;

-- 04.착용일이면서 만보 이상
SELECT "Id", "ActivityDate", "TotalSteps"
FROM daily_features
WHERE is_worn = TRUE
  AND "TotalSteps" >= 10000;

-- 05.걸음수가 아주 적거나 아주 많은 날
SELECT "Id", "ActivityDate", "TotalSteps"
FROM daily_features
WHERE "TotalSteps" < 2000
   OR "TotalSteps" > 20000;

-- 06.5000~10000보 구간
SELECT "Id", "ActivityDate", "TotalSteps"
FROM daily_features
WHERE "TotalSteps" BETWEEN 5000 AND 10000;

-- 07.특정 요일만 필터
SELECT "Id", "ActivityDate", weekday
FROM daily_features
WHERE weekday IN ('Saturday', 'Sunday');

-- 08.특정 요일 이름에 'day' 포함 (예시용)
SELECT DISTINCT weekday
FROM daily_features
WHERE weekday LIKE '%day';

-- 09.수면기록 없는 날
SELECT "Id", "ActivityDate"
FROM daily_features
WHERE "TotalMinutesAsleep" IS NULL;

-- 10.수면기록 있는 날만
SELECT "Id", "ActivityDate", "TotalMinutesAsleep"
FROM daily_features
WHERE "TotalMinutesAsleep" IS NOT NULL;

-- 11.걸음수 많은 순
SELECT "Id", "ActivityDate", "TotalSteps"
FROM daily_features
ORDER BY "TotalSteps" DESC;

-- 12.Id 오름차순, 날짜 오름차순
SELECT "Id", "ActivityDate", "TotalSteps"
FROM daily_features
ORDER BY "Id" ASC, "ActivityDate" ASC;

-- 13.상위 10일
SELECT "Id", "ActivityDate", "TotalSteps"
FROM daily_features
ORDER BY "TotalSteps" DESC
LIMIT 10;

-- 14.존재하는 요일 종류
SELECT DISTINCT weekday
FROM daily_features;

-- 15.사용자별 존재하는 요일 조합 수는 아니고, 단순 예시
SELECT DISTINCT "Id", is_weekend
FROM daily_features;

-- 16.전체 착용일수
SELECT COUNT(*) AS worn_day_count
FROM daily_features
WHERE is_worn = TRUE;

-- 17.전체 사용자 총 걸음수 합계
SELECT SUM("TotalSteps") AS total_steps_all_users
FROM daily_features
WHERE is_worn = TRUE;

-- 18.전체 평균 걸음수
SELECT ROUND(AVG("TotalSteps"), 1) AS avg_steps
FROM daily_features
WHERE is_worn = TRUE;

-- 19.걸음수 최소·최대값
SELECT MIN("TotalSteps") AS min_steps, MAX("TotalSteps") AS max_steps
FROM daily_features
WHERE is_worn = TRUE;

-- 20.사용자별 평균 걸음수
SELECT "Id", ROUND(AVG("TotalSteps"), 1) AS avg_steps
FROM daily_features
WHERE is_worn = TRUE
GROUP BY "Id"
ORDER BY avg_steps DESC;

-- 21.사용자×주말여부 평균 걸음수
SELECT "Id", is_weekend, ROUND(AVG("TotalSteps"), 1) AS avg_steps
FROM daily_features
WHERE is_worn = TRUE
GROUP BY "Id", is_weekend
ORDER BY "Id", is_weekend;

-- 22.평균 걸음수 8000 이상인 사용자에 라벨 부여
SELECT
    "Id",
    ROUND(AVG("TotalSteps"), 1) AS avg_steps,
    CASE
        WHEN AVG("TotalSteps") < 5000  THEN 'Low'
        WHEN AVG("TotalSteps") < 10000 THEN 'Moderate'
        ELSE 'High'
    END AS activity_level
FROM daily_features
WHERE is_worn = TRUE
GROUP BY "Id"
HAVING AVG("TotalSteps") >= 3000
ORDER BY avg_steps DESC;