USE fitbit_retention;

-- 01.수면기록 있는 날
SELECT `Id`, `ActivityDate`, `TotalSteps`, `TotalMinutesAsleep`
FROM daily_features
WHERE `TotalMinutesAsleep` IS NOT NULL;

-- 02.전체 활동일 (수면기록 유무 상관없이)
SELECT `Id`, `ActivityDate`, `TotalSteps`, `TotalMinutesAsleep`
FROM daily_features;

-- 03.수면 기록이 없는 활동일만 추출
SELECT `Id`, `ActivityDate`
FROM daily_features
WHERE `TotalMinutesAsleep` IS NULL;

-- 04.활동 + 수면 + 체중기록빈도
SELECT a.`Id`, a.`ActivityDate`, a.`TotalSteps`, a.`TotalMinutesAsleep`, u.`WeightLogCount`
FROM daily_features a
JOIN user_summary u ON a.`Id` = u.`Id`;

-- 05.같은 사용자의 전날 걸음수와 비교 (SELF JOIN)
SELECT
    t1.`Id`,
    t1.`ActivityDate`        AS today,
    t1.`TotalSteps`          AS steps_today,
    t2.`TotalSteps`          AS steps_yesterday
FROM daily_features t1
JOIN daily_features t2
    ON t1.`Id` = t2.`Id`
   AND t2.`ActivityDate` = t1.`ActivityDate` - INTERVAL 1 DAY;

-- 06.전체 평균보다 활동량 높은 사용자 (서브쿼리)
SELECT `Id`, ROUND(AVG(`TotalSteps`),1) AS avg_steps
FROM daily_features
WHERE is_worn = TRUE
GROUP BY `Id`
HAVING AVG(`TotalSteps`) > (
    SELECT AVG(`TotalSteps`) FROM daily_features WHERE is_worn = TRUE
);

-- 07.전체 평균 대비 개인 평균 차이
SELECT
    `Id`,
    ROUND(AVG(`TotalSteps`), 1) AS avg_steps,
    ROUND(AVG(`TotalSteps`) - (SELECT AVG(`TotalSteps`) FROM daily_features WHERE is_worn = TRUE), 1) AS diff_from_overall_avg
FROM daily_features
WHERE is_worn = TRUE
GROUP BY `Id`;

-- 08.사용자별 요약 후 재필터링 (인라인뷰)
SELECT *
FROM (
    SELECT `Id`, ROUND(AVG(`TotalSteps`),1) AS avg_steps
    FROM daily_features
    WHERE is_worn = TRUE
    GROUP BY `Id`
) sub
WHERE avg_steps > 8000;

-- 09.체중 기록이 있는 사용자만
SELECT `Id`, `WeightLogCount`
FROM user_summary
WHERE `WeightLogCount` > 0;

-- 10.심박 기록이 전혀 없는 사용자
SELECT `Id`
FROM user_summary
WHERE `HasHeartRate` = FALSE;

-- 11.저활동군 + 고활동군 사용자 Id 합치기(중복 제거)
SELECT `Id` FROM daily_features WHERE `TotalSteps` < 3000
UNION
SELECT `Id` FROM daily_features WHERE `TotalSteps` > 15000;

-- 12.중복 허용하고 합치기
SELECT `Id`, 'low_day' AS tag FROM daily_features WHERE `TotalSteps` < 3000
UNION ALL
SELECT `Id`, 'high_day' AS tag FROM daily_features WHERE `TotalSteps` > 15000;

-- 13.사용자별 평균 걸음수와 클러스터 페르소나 함께 보기
SELECT u.`Persona`, a.`Id`, ROUND(AVG(a.`TotalSteps`),1) AS avg_steps
FROM daily_features a
JOIN user_summary_clustered u ON a.`Id` = u.`Id`
WHERE a.is_worn = TRUE
GROUP BY u.`Persona`, a.`Id`
ORDER BY u.`Persona`, avg_steps DESC;

-- 14.사용자별 지속률 계산
WITH wear_stats AS (
    SELECT
        `Id`,
        COUNT(*) AS observed_days,
        SUM(CASE WHEN is_worn THEN 1 ELSE 0 END) AS worn_days
    FROM daily_features
    GROUP BY `Id`
)
SELECT `Id`, observed_days, worn_days,
       ROUND(worn_days / observed_days, 3) AS wear_rate
FROM wear_stats
ORDER BY wear_rate DESC;

-- 15.지속률 계산 후 상/하위 그룹 나누기 (NTILE)
WITH wear_stats AS (
    SELECT `Id`,
           SUM(CASE WHEN is_worn THEN 1 ELSE 0 END) / COUNT(*) AS wear_rate
    FROM daily_features
    GROUP BY `Id`
),
ranked AS (
    SELECT *, NTILE(5) OVER (ORDER BY wear_rate) AS quintile
    FROM wear_stats
)
SELECT `Id`, wear_rate,
       CASE WHEN quintile = 5 THEN '상위 20%'
            WHEN quintile = 1 THEN '하위 20%'
            ELSE '중간' END AS group_label
FROM ranked
ORDER BY wear_rate DESC;

-- 16.요일명 대문자 변환, 앞 3글자만
SELECT `Id`, `ActivityDate`, UPPER(LEFT(weekday, 3)) AS weekday_short
FROM daily_features;

-- 17.월, 연도 추출
SELECT
    `Id`,
    `ActivityDate`,
    MONTH(`ActivityDate`) AS activity_month,
    YEAR(`ActivityDate`) AS activity_year
FROM daily_features;

-- 18.수면기록 없으면 0으로 대체해서 평균 계산
SELECT
    `Id`,
    ROUND(AVG(COALESCE(`TotalMinutesAsleep`, 0)), 1) AS avg_sleep_incl_missing
FROM daily_features
GROUP BY `Id`;

-- 19.걸음수를 텍스트로 변환해 라벨 합치기
SELECT
    `Id`,
    `ActivityDate`,
    CONCAT(CAST(`TotalSteps` AS CHAR), '보') AS steps_label
FROM daily_features
LIMIT 20;

-- 20.활동수준 + 주말여부 동시 라벨링
SELECT
    `Id`, `ActivityDate`, `TotalSteps`, is_weekend,
    CASE
        WHEN `TotalSteps` >= 10000 AND is_weekend THEN 'High-Weekend'
        WHEN `TotalSteps` >= 10000 AND NOT is_weekend THEN 'High-Weekday'
        WHEN `TotalSteps` < 5000 THEN 'Low'
        ELSE 'Moderate'
    END AS segment
FROM daily_features
WHERE is_worn = TRUE;

-- 21.사용자별 착용일 중 만보 달성 비율(%)
SELECT
    `Id`,
    ROUND(
        100.0 * SUM(CASE WHEN `TotalSteps` >= 10000 THEN 1 ELSE 0 END) / COUNT(*), 1
    ) AS pct_days_over_10k
FROM daily_features
WHERE is_worn = TRUE
GROUP BY `Id`
ORDER BY pct_days_over_10k DESC;