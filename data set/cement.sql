-- ------------------------------------------------------------------------------------------------
--  CEMENT MANUFACTURING DATA ANALYSIS SCRIPT
--  THIS SCRIPT PERFORMS VARIOUS DATA ANALYSIS TASKS ON CEMENT MANUFACTURING DATA,
--  INCLUDING DATA CLEANING, DESCRIPTIVE STATISTICS, OUTLIER DETECTION,
--  PERFORMANCE ANALYSIS, PREDICTIVE MAINTENANCE, AND TREND FORECASTING.
-- ------------------------------------------------------------------------------------------------

-- CREATE AND USE DATABASE
CREATE DATABASE  PRACTISEDB

USE PRACTISEDB;

-- ------------------------------------------------------------------------------------------------
--  1. BASIC DATA EXPLORATION
-- ------------------------------------------------------------------------------------------------

-- COUNT THE TOTAL NUMBER OF ROWS IN THE `CEMENT` TABLE
SELECT COUNT(*) AS TOTAL_NO_OF_ROWS
FROM CEMENT;

-- RETRIEVE AND DISPLAY THE FIRST 10 ROWS FROM THE `CEMENT` TABLE
SELECT TOP 10 *
FROM CEMENT


-- ------------------------------------------------------------------------------------------------
--  2. DATA CLEANING & OPTIMIZATION
-- ------------------------------------------------------------------------------------------------

-- CHECKING FOR NULL VALUES IN ALL COLUMNS
SELECT
    COLUMN_NAME,
    COUNT(*) AS NULL_COUNT
FROM
    INFORMATION_SCHEMA.COLUMNS
WHERE
    TABLE_NAME = 'CEMENT'
GROUP BY
    COLUMN_NAME
ORDER BY
    COLUMN_NAME;

-- REMOVING NULL VALUES FROM THE `MILL TPH` COLUMN
DELETE FROM CEMENT
WHERE `MILL TPH` IS NULL;

-- CHECKING FOR DUPLICATE RECORDS BASED ON KEY COLUMNS
SELECT
    `DATE & TIME`,
    `MILL TPH`,
    `CLINKER TPH`,
    `GYPSUM TPH`,
    `DFA TPH`,
    `WFA TPH`,
    `MILL KW`,
    `MILL I/L TEMP`,
    `MILL O/L TEMP`,
    COUNT(*) AS RECORD_COUNT
FROM
    CEMENT
GROUP BY
    `DATE & TIME`,
    `MILL TPH`,
    `CLINKER TPH`,
    `GYPSUM TPH`,
    `DFA TPH`,
    `WFA TPH`,
    `MILL KW`,
    `MILL I/L TEMP`,
    `MILL O/L TEMP`
HAVING
    COUNT(*) > 1;

-- REMOVING DUPLICATE RECORDS, KEEPING THE ONE WITH THE EARLIEST `DATE & TIME`
DELETE C1
FROM
    CEMENT C1
    JOIN (
        SELECT
            MIN(`DATE & TIME`) AS MIN_DATE_TIME,
            `MILL TPH`,
            `CLINKER TPH`,
            `GYPSUM TPH`,
            `DFA TPH`,
            `WFA TPH`,
            `MILL KW`,
            `MILL I/L TEMP`,
            `MILL O/L TEMP`
        FROM
            CEMENT
        GROUP BY
            `MILL TPH`,
            `CLINKER TPH`,
            `GYPSUM TPH`,
            `DFA TPH`,
            `WFA TPH`,
            `MILL KW`,
            `MILL I/L TEMP`,
            `MILL O/L TEMP`
    ) C2 ON C1.`MILL TPH` = C2.`MILL TPH`
    AND C1.`CLINKER TPH` = C2.`CLINKER TPH`
    AND C1.`GYPSUM TPH` = C2.`GYPSUM TPH`
    AND C1.`DFA TPH` = C2.`DFA TPH`
    AND C1.`WFA TPH` = C2.`WFA TPH`
    AND C1.`MILL KW` = C2.`MILL KW`
    AND C1.`MILL I/L TEMP` = C2.`MILL I/L TEMP`
    AND C1.`MILL O/L TEMP` = C2.`MILL O/L TEMP`
    AND C1.`DATE & TIME` > C2.MIN_DATE_TIME;  -- ONLY DELETE IF THE DATETIME IS *LATER* THAN THE MINIMUM

-- ------------------------------------------------------------------------------------------------
--  3. EXTENDED DESCRIPTIVE ANALYSIS
-- ------------------------------------------------------------------------------------------------

-- BASIC STATISTICS FOR MILL TPH
SELECT
    COUNT(*) AS TOTAL_ROWS,
    AVG(`MILL TPH`) AS AVG_MILL_TPH,
    MIN(`MILL TPH`) AS MIN_MILL_TPH,
    MAX(`MILL TPH`) AS MAX_MILL_TPH,
    STDDEV(`MILL TPH`) AS STDDEV_MILL_TPH,
    VARIANCE(`MILL TPH`) AS VARIANCE_MILL_TPH,
    (
        SELECT
            SUM(POWER(`MILL TPH` - (
                SELECT AVG(`MILL TPH`)
                FROM CEMENT
            ), 3)) / (COUNT(*) * POWER((
                SELECT STDDEV(`MILL TPH`)
                FROM CEMENT
            ), 3))
    ) AS SKEWNESS_MILL_TPH,
    (
        SELECT
            SUM(POWER(`MILL TPH` - (
                SELECT AVG(`MILL TPH`)
                FROM CEMENT
            ), 4)) / (COUNT(*) * POWER((
                SELECT VARIANCE(`MILL TPH`)
                FROM CEMENT
            ), 2))
    ) AS KURTOSIS_MILL_TPH
FROM
    CEMENT;

-- BASIC STATISTICS FOR MILL KW
SELECT
    COUNT(*) AS TOTAL_ROWS,
    AVG(`MILL KW`) AS AVG_MILL_KW,
    MIN(`MILL KW`) AS MIN_MILL_KW,
    MAX(`MILL KW`) AS MAX_MILL_KW,
    STDDEV(`MILL KW`) AS STDDEV_MILL_KW,
    VARIANCE(`MILL KW`) AS VARIANCE_MILL_KW,
    (
        SELECT
            SUM(POWER(`MILL KW` - (
                SELECT AVG(`MILL KW`)
                FROM CEMENT
            ), 3)) / (COUNT(*) * POWER((
                SELECT STDDEV(`MILL KW`)
                FROM CEMENT
            ), 3))
    ) AS SKEWNESS_MILL_KW,
    (
        SELECT
            SUM(POWER(`MILL KW` - (
                SELECT AVG(`MILL KW`)
                FROM CEMENT
            ), 4)) / (COUNT(*) * POWER((
                SELECT VARIANCE(`MILL KW`)
                FROM CEMENT
            ), 2))
    ) AS KURTOSIS_MILL_KW
FROM
    CEMENT;

-- ------------------------------------------------------------------------------------------------
--  4. HANDLING OUTLIERS USING INTERQUARTILE RANGE (IQR) METHOD
-- ------------------------------------------------------------------------------------------------
-- NOTE: THIS QUERY IDENTIFIES OUTLIERS BUT DOES NOT REMOVE THEM.

WITH RANKED AS (
    SELECT
        `DATE & TIME`,
        `MILL TPH`,
        `CLINKER TPH`,
        `MILL KW`,
        `SEP RPM`,
        `RESIDUE`,
        ROW_NUMBER() OVER (ORDER BY `MILL TPH`) AS MILL_RANK,
        ROW_NUMBER() OVER (ORDER BY `CLINKER TPH`) AS CLINKER_RANK,
        COUNT(*) OVER () AS TOTAL_ROWS
    FROM
        CEMENT
), QUARTILES AS (
    SELECT
        (
            SELECT `MILL TPH`
            FROM RANKED
            WHERE MILL_RANK = FLOOR(0.25 * TOTAL_ROWS)
            LIMIT 1
        ) AS Q1_MILL_TPH,
        (
            SELECT `MILL TPH`
            FROM RANKED
            WHERE MILL_RANK = FLOOR(0.75 * TOTAL_ROWS)
            LIMIT 1
        ) AS Q3_MILL_TPH,
        (
            SELECT `CLINKER TPH`
            FROM RANKED
            WHERE CLINKER_RANK = FLOOR(0.25 * TOTAL_ROWS)
            LIMIT 1
        ) AS Q1_CLINKER_TPH,
        (
            SELECT `CLINKER TPH`
            FROM RANKED
            WHERE CLINKER_RANK = FLOOR(0.75 * TOTAL_ROWS)
            LIMIT 1
        ) AS Q3_CLINKER_TPH
    FROM
        RANKED
)
SELECT
    C.`DATE & TIME`,
    C.`MILL TPH`,
    C.`CLINKER TPH`,
    C.`MILL KW`,
    C.`SEP RPM`,
    C.`RESIDUE`
FROM
    CEMENT C
    JOIN QUARTILES Q ON 1 = 1  -- ENSURES THE SUBQUERY RETURNS A SINGLE ROW
WHERE
    C.`MILL TPH` < (Q.Q1_MILL_TPH - 1.5 * (Q.Q3_MILL_TPH - Q.Q1_MILL_TPH))
    OR C.`MILL TPH` > (Q.Q3_MILL_TPH + 1.5 * (Q.Q3_MILL_TPH - Q.Q1_MILL_TPH))
    OR C.`CLINKER TPH` < (Q.Q1_CLINKER_TPH - 1.5 * (Q.Q3_CLINKER_TPH - Q.Q1_CLINKER_TPH))
    OR C.`CLINKER TPH` > (Q.Q3_CLINKER_TPH + 1.5 * (Q.Q3_CLINKER_TPH - Q.Q1_CLINKER_TPH))
ORDER BY
    C.`DATE & TIME` DESC;

-- ------------------------------------------------------------------------------------------------
--  5. PERFORMANCE & EFFICIENCY INSIGHTS
-- ------------------------------------------------------------------------------------------------

-- CORRELATION BETWEEN MILL POWER & PRODUCTION
SELECT
    (
        SUM((`MILL TPH` - TEMP.AVG_MILL_TPH) * (`MILL KW` - TEMP.AVG_MILL_KW)) / (SQRT(SUM(POW(`MILL TPH` - TEMP.AVG_MILL_TPH, 2))) * SQRT(SUM(POW(`MILL KW` - TEMP.AVG_MILL_KW, 2))))
    ) AS CORRELATION_MILL_TPH_KW
FROM
    CEMENT,
    (
        SELECT
            AVG(`MILL TPH`) AS AVG_MILL_TPH,
            AVG(`MILL KW`) AS AVG_MILL_KW
        FROM
            CEMENT
    ) AS TEMP;

-- IMPACT OF TEMPERATURE ON PERFORMANCE
SELECT
    AVG(`MILL I/L TEMP`) AS AVG_MILL_IL_TEMP,
    AVG(`MILL O/L TEMP`) AS AVG_MILL_OL_TEMP,
    AVG(`MILL TPH`) AS AVG_MILL_TPH
FROM
    CEMENT;

-- SEPARATOR RPM VS. MILL PERFORMANCE
SELECT
    `SEP RPM`,
    AVG(`MILL TPH`) AS AVG_MILL_TPH
FROM
    CEMENT
GROUP BY
    `SEP RPM`;

-- MILL FAN POWER VS. PRODUCTION RATE
SELECT
    `MILL VENT FAN KW`,
    AVG(`MILL TPH`) AS AVG_MILL_TPH
FROM
    CEMENT
GROUP BY
    `MILL VENT FAN KW`;

-- RESIDUE VS. PRODUCTION
SELECT
    `RESIDUE`,
    AVG(`MILL TPH`) AS AVG_MILL_TPH
FROM
    CEMENT
GROUP BY
    `RESIDUE`;

-- ------------------------------------------------------------------------------------------------
--  6. REAL-TIME MONITORING VIEWS
-- ------------------------------------------------------------------------------------------------

-- CREATE A LIVE DATA VIEW
CREATE OR REPLACE VIEW CEMENT_DASHBOARD AS
SELECT
    `DATE & TIME`,
    `MILL TPH`,
    `MILL KW`,
    `SEP RPM`,
    `RESIDUE`,
    `REJECT`,
    `MILL I/L TEMP`,
    `MILL O/L TEMP`
FROM
    CEMENT
ORDER BY
    `DATE & TIME` DESC;

-- IDENTIFY UNDERPERFORMING PERIODS
SELECT
    `DATE & TIME`,
    `MILL TPH`,
    `MILL KW`
FROM
    CEMENT
WHERE
    `MILL TPH` < (
        SELECT
            AVG(`MILL TPH`)
        FROM
            CEMENT
    ) * 0.8
ORDER BY
    `DATE & TIME` DESC;

-- POWER CONSUMPTION EXTREMES
SELECT
    MIN(`MILL KW`) AS MIN_POWER,
    MAX(`MILL KW`) AS MAX_POWER
FROM
    CEMENT;

-- ------------------------------------------------------------------------------------------------
--  7. ALERTS & ANOMALIES
-- ------------------------------------------------------------------------------------------------

-- REJECT RATE ALERT
SELECT
    `DATE & TIME`,
    `REJECT`
FROM
    CEMENT
WHERE
    `REJECT` > (
        SELECT
            AVG(`REJECT`)
        FROM
            CEMENT
    ) * 1.5;

-- HIGH TEMPERATURE ALERT
SELECT
    `DATE & TIME`,
    `MILL I/L TEMP`,
    `MILL O/L TEMP`
FROM
    CEMENT
WHERE
    `MILL O/L TEMP` > 100;

-- SEPARATOR INEFFICIENCY ALERT
SELECT
    `DATE & TIME`,
    `SEP RPM`,
    `SEP KW`
FROM
    CEMENT
WHERE
    `SEP KW` > (
        SELECT
            AVG(`SEP KW`)
        FROM
            CEMENT
    ) * 1.3;

-- ------------------------------------------------------------------------------------------------
--  8. PREDICTIVE MAINTENANCE QUERIES
-- ------------------------------------------------------------------------------------------------

-- PREDICTIVE MAINTENANCE QUERIES
SELECT
    `DATE & TIME`,
    `SEP RPM`,
    `MILL VENT FAN KW`,
    `MILL VENT FAN RPM`,
    `SEP KW`
FROM
    CEMENT
WHERE
    `MILL VENT FAN KW` > (
        SELECT
            AVG(`MILL VENT FAN KW`)
        FROM
            CEMENT
    ) * 1.2
    OR `SEP KW` > (
        SELECT
            AVG(`SEP KW`)
        FROM
            CEMENT
    ) * 1.2
ORDER BY
    `DATE & TIME` DESC;

-- (IF FAN POWER OR SEPARATOR KW INCREASES OVER TIME, IT MIGHT INDICATE WEAR AND TEAR, REQUIRING MAINTENANCE.)

-- IDENTIFY UNUSUAL POWER CONSUMPTION SPIKES
SELECT
    `DATE & TIME`,
    `MILL KW`,
    `SEP KW`,
    `CA FAN KW`
FROM
    CEMENT
WHERE
    `MILL KW` > (
        SELECT
            AVG(`MILL KW`)
        FROM
            CEMENT
    ) * 1.2
    OR `SEP KW` > (
        SELECT
            AVG(`SEP KW`)
        FROM
            CEMENT
    ) * 1.2
    OR `CA FAN KW` > (
        SELECT
            AVG(`CA FAN KW`)
        FROM
            CEMENT
    ) * 1.2
ORDER BY
    `DATE & TIME` DESC;

-- (SUDDEN JUMPS IN KW USAGE COULD INDICATE MOTOR DEGRADATION, LOAD IMBALANCE, OR MECHANICAL INEFFICIENCIES.)

-- PREDICTIVE FAN FAILURE (RPM & KW CORRELATION)
SELECT
    `MILL VENT FAN RPM`,
    `MILL VENT FAN KW`,
    COUNT(*) AS OCCURRENCES
FROM
    CEMENT
WHERE
    `MILL VENT FAN RPM` IS NOT NULL
    AND `MILL VENT FAN KW` IS NOT NULL
    AND `MILL VENT FAN RPM` < (
        SELECT
            AVG(`MILL VENT FAN RPM`)
        FROM
            CEMENT
        WHERE
            `MILL VENT FAN RPM` IS NOT NULL
    ) * 0.85
    AND `MILL VENT FAN KW` > (
        SELECT
            AVG(`MILL VENT FAN KW`)
        FROM
            CEMENT
        WHERE
            `MILL VENT FAN KW` IS NOT NULL
    ) * 1.1
GROUP BY
    `MILL VENT FAN RPM`,
    `MILL VENT FAN KW`
ORDER BY
    OCCURRENCES DESC;

-- (A FAN CONSUMING HIGH POWER WITH LOWER RPM MAY INDICATE BELT SLIPPAGE OR MECHANICAL FAILURE.)

-- DETECT SEPARATOR WEAR & INEFFICIENCY
SELECT
    MIN(`SEP RPM`) AS MIN_SEP_RPM,
    MAX(`SEP RPM`) AS MAX_SEP_RPM,
    MIN(`RESIDUE`) AS MIN_RESIDUE,
    MAX(`RESIDUE`) AS MAX_RESIDUE
FROM
    CEMENT;

-- (IF MIN(SEP RPM) > (AVG(SEP RPM) * 0.8), THEN NO VALUES CAN SATISFY THE CONDITION, IF MAX(RESIDUE) < (AVG(RESIDUE) * 1.2), THEN NO VALUES CAN SATISFY THE CONDITION.)
-- (SEP RPM MUST BE LESS THAN 952.12 * 0.8 = 761.69, RESIDUE MUST BE GREATER THAN 15.19 * 1.2 = 18.23)
SELECT
    `DATE & TIME`,
    `SEP RPM`,
    `RESIDUE`
FROM
    CEMENT
WHERE
    `SEP RPM` < (
        SELECT
            AVG(`SEP RPM`)
        FROM
            CEMENT
    ) * 0.95  -- CHANGED FROM 0.8 TO 0.95
    AND `RESIDUE` > (
        SELECT
            AVG(`RESIDUE`)
        FROM
            CEMENT
    ) * 1.1  -- CHANGED FROM 1.2 TO 1.1
ORDER BY
    `DATE & TIME` DESC;

-- (IF THE SEPARATOR RPM IS LOW AND RESIDUE IS HIGH, IT MAY INDICATE SEPARATOR BLADE WEAR.)

-- PREDICT CEMENT QUALITY DEGRADATION
SELECT
    `DATE & TIME`,
    AVG(`RESIDUE`) OVER (
        ORDER BY
            `DATE & TIME` ROWS BETWEEN 10 PRECEDING AND CURRENT ROW
    ) AS ROLLING_AVG_RESIDUE
FROM
    CEMENT
ORDER BY
    `DATE & TIME` DESC;

-- (A GRADUAL INCREASE IN ROLLING AVERAGE RESIDUE INDICATES A DECLINE IN CEMENT FINENESS, REQUIRING SEPARATOR ADJUSTMENT.)

-- PREDICTIVE MAINTENANCE ALERTS BASED ON RUNNING HOURS
SELECT
    `MILL KW`,
    COUNT(*) AS RUNNING_HOURS,
    CASE
        WHEN COUNT(*) > 100 THEN 'MAINTENANCE REQUIRED'
        ELSE 'RUNNING NORMALLY'
    END AS MAINTENANCE_STATUS
FROM
    CEMENT
GROUP BY
    `MILL KW`;

-- (IF EQUIPMENT HAS RUN CONTINUOUSLY FOR OVER 100 HOURS, SCHEDULE MAINTENANCE.)

-- TEMPERATURE-BASED EQUIPMENT FAILURE PREDICTION
SELECT
    `DATE & TIME`,
    `MILL O/L TEMP`,
    `MILL I/L TEMP`
FROM
    CEMENT
WHERE
    `MILL O/L TEMP` > (
        SELECT
            AVG(`MILL O/L TEMP`)
        FROM
            CEMENT
    ) * 1.3
ORDER BY
    `DATE & TIME` DESC;

-- (A 30% RISE IN OUTLET TEMPERATURE SUGGESTS BEARING WEAR, LUBRICATION ISSUES, OR HEAT DISSIPATION FAILURE)

-- ------------------------------------------------------------------------------------------------
--  9. TREND FORECASTING QUERIES
-- ------------------------------------------------------------------------------------------------

-- MONTHLY TREND OF PRODUCTION EFFICIENCY
SELECT
    DATE_FORMAT(STR_TO_DATE(`DATE & TIME`, '%M/%D/%Y %H:%I'), '%Y-%M') AS MONTH,
    AVG(`MILL TPH`) AS AVG_PRODUCTION,
    AVG(`MILL KW`) AS AVG_POWER
FROM
    CEMENT
WHERE
    `DATE & TIME` IS NOT NULL
GROUP BY
    DATE_FORMAT(STR_TO_DATE(`DATE & TIME`, '%M/%D/%Y %H:%I'), '%Y-%M')
ORDER BY
    MONTH DESC;

-- (HELPS TRACK MONTHLY PRODUCTION EFFICIENCY AND POWER CONSUMPTION TRENDS.)

-- LONG-TERM SEPARATOR PERFORMANCE TREND
SELECT
    DATE_FORMAT(STR_TO_DATE(`DATE & TIME`, '%M/%D/%Y %H:%I'), '%Y-%M') AS MONTH,
    AVG(`SEP RPM`) AS AVG_SEP_RPM,
    AVG(`RESIDUE`) AS AVG_RESIDUE
FROM
    CEMENT
WHERE
    `DATE & TIME` IS NOT NULL
GROUP BY
    DATE_FORMAT(STR_TO_DATE(`DATE & TIME`, '%M/%D/%Y %H:%I'), '%Y-%M')
ORDER BY
    MONTH DESC;

-- (SHOWS IF SEPARATOR PERFORMANCE IS DEGRADING OVER TIME.)

-- TREND IN ENERGY CONSUMPTION VS. OUTPUT
SELECT
    DATE_FORMAT(STR_TO_DATE(`DATE & TIME`, '%M/%D/%Y %H:%I'), '%Y-%M') AS MONTH,
    SUM(`MILL KW`) / SUM(`MILL TPH`) AS ENERGY_PER_TON
FROM
    CEMENT
GROUP BY
    DATE_FORMAT(STR_TO_DATE(`DATE & TIME`, '%M/%D/%Y %H:%I'), '%Y-%M')
ORDER BY
    MONTH DESC;

-- (HELPS IDENTIFY RISING ENERGY CONSUMPTION PER TON—A SIGN OF INEFFICIENCIES.)

-- FORECAST FUTURE CEMENT MILL EFFICIENCY
SELECT
    DATE_FORMAT(STR_TO_DATE(`DATE & TIME`, '%M/%D/%Y %H:%I'), '%Y-%M') AS MONTH,
    AVG(`MILL TPH`) AS AVG_PRODUCTION,
    LAG(AVG(`MILL TPH`), 1) OVER (
        ORDER BY
            DATE_FORMAT(STR_TO_DATE(`DATE & TIME`, '%M/%D/%Y %H:%I'), '%Y-%M')
    ) AS PREV_MONTH_PRODUCTION,
    (
        AVG(`MILL TPH`) - LAG(AVG(`MILL TPH`), 1) OVER (
            ORDER BY
                DATE_FORMAT(STR_TO_DATE(`DATE & TIME`, '%M/%D/%Y %H:%I'), '%Y-%M')
        )
    ) / LAG(AVG(`MILL TPH`), 1) OVER (
        ORDER BY
            DATE_FORMAT(STR_TO_DATE(`DATE & TIME`, '%M/%D/%Y %H:%I'), '%Y-%M')
    ) * 100 AS PRODUCTION_GROWTH
FROM
    CEMENT
GROUP BY
    DATE_FORMAT(STR_TO_DATE(`DATE & TIME`, '%M/%D/%Y %H:%I'), '%Y-%M')
ORDER BY
    MONTH DESC;

-- (PROVIDES A MONTH-OVER-MONTH PRODUCTION TREND AND GROWTH PERCENTAGE.)
