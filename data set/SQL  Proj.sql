-- ------------------------------------------------------------------------------------------------
--  Cement Manufacturing Data Analysis Script
--  This script performs various data analysis tasks on cement manufacturing data,
--  including data cleaning, descriptive statistics, outlier detection,
--  performance analysis, predictive maintenance, and trend forecasting.
-- ------------------------------------------------------------------------------------------------

-- Create and Use Database
CREATE DATABASE IF NOT EXISTS cement_manufacture;

USE cement_manufacture;

-- ------------------------------------------------------------------------------------------------
--  1. Basic Data Exploration
-- ------------------------------------------------------------------------------------------------

-- Count the total number of rows in the `cement` table
SELECT COUNT(*) AS total_no_of_rows
FROM cement;

-- Retrieve and display the first 10 rows from the `cement` table
SELECT *
FROM cement
LIMIT 10;

-- ------------------------------------------------------------------------------------------------
--  2. Data Cleaning & Optimization
-- ------------------------------------------------------------------------------------------------

-- Checking for NULL values in all columns
SELECT
    column_name,
    COUNT(*) AS null_count
FROM
    information_schema.columns
WHERE
    table_name = 'cement'
GROUP BY
    column_name
ORDER BY
    column_name;

-- Removing NULL values from the `Mill TPH` column
DELETE FROM cement
WHERE `Mill TPH` IS NULL;

-- Checking for duplicate records based on key columns
SELECT
    `Date & Time`,
    `Mill TPH`,
    `Clinker TPH`,
    `Gypsum TPH`,
    `DFA TPH`,
    `WFA TPH`,
    `Mill KW`,
    `Mill I/L Temp`,
    `Mill O/L Temp`,
    COUNT(*) AS record_count
FROM
    cement
GROUP BY
    `Date & Time`,
    `Mill TPH`,
    `Clinker TPH`,
    `Gypsum TPH`,
    `DFA TPH`,
    `WFA TPH`,
    `Mill KW`,
    `Mill I/L Temp`,
    `Mill O/L Temp`
HAVING
    COUNT(*) > 1;

-- Removing duplicate records, keeping the one with the earliest `Date & Time`
DELETE c1
FROM
    cement c1
    JOIN (
        SELECT
            MIN(`Date & Time`) AS min_date_time,
            `Mill TPH`,
            `Clinker TPH`,
            `Gypsum TPH`,
            `DFA TPH`,
            `WFA TPH`,
            `Mill KW`,
            `Mill I/L Temp`,
            `Mill O/L Temp`
        FROM
            cement
        GROUP BY
            `Mill TPH`,
            `Clinker TPH`,
            `Gypsum TPH`,
            `DFA TPH`,
            `WFA TPH`,
            `Mill KW`,
            `Mill I/L Temp`,
            `Mill O/L Temp`
    ) c2 ON c1.`Mill TPH` = c2.`Mill TPH`
    AND c1.`Clinker TPH` = c2.`Clinker TPH`
    AND c1.`Gypsum TPH` = c2.`Gypsum TPH`
    AND c1.`DFA TPH` = c2.`DFA TPH`
    AND c1.`WFA TPH` = c2.`WFA TPH`
    AND c1.`Mill KW` = c2.`Mill KW`
    AND c1.`Mill I/L Temp` = c2.`Mill I/L Temp`
    AND c1.`Mill O/L Temp` = c2.`Mill O/L Temp`
    AND c1.`Date & Time` > c2.min_date_time;  -- Only delete if the datetime is *later* than the minimum

-- ------------------------------------------------------------------------------------------------
--  3. Extended Descriptive Analysis
-- ------------------------------------------------------------------------------------------------

-- Basic Statistics for Mill TPH
SELECT
    COUNT(*) AS total_rows,
    AVG(`mill tph`) AS avg_mill_tph,
    MIN(`mill tph`) AS min_mill_tph,
    MAX(`mill tph`) AS max_mill_tph,
    STDDEV(`mill tph`) AS stddev_mill_tph,
    VARIANCE(`mill tph`) AS variance_mill_tph,
    (
        SELECT
            SUM(POWER(`Mill TPH` - (
                SELECT AVG(`Mill TPH`)
                FROM cement
            ), 3)) / (COUNT(*) * POWER((
                SELECT STDDEV(`Mill TPH`)
                FROM cement
            ), 3))
    ) AS skewness_mill_tph,
    (
        SELECT
            SUM(POWER(`Mill TPH` - (
                SELECT AVG(`Mill TPH`)
                FROM cement
            ), 4)) / (COUNT(*) * POWER((
                SELECT VARIANCE(`Mill TPH`)
                FROM cement
            ), 2))
    ) AS kurtosis_mill_tph
FROM
    cement;

-- Basic Statistics for Mill KW
SELECT
    COUNT(*) AS total_rows,
    AVG(`mill KW`) AS avg_mill_kw,
    MIN(`mill KW`) AS min_mill_kw,
    MAX(`mill KW`) AS max_mill_kw,
    STDDEV(`mill KW`) AS stddev_mill_kw,
    VARIANCE(`mill KW`) AS variance_mill_kw,
    (
        SELECT
            SUM(POWER(`Mill KW` - (
                SELECT AVG(`Mill KW`)
                FROM cement
            ), 3)) / (COUNT(*) * POWER((
                SELECT STDDEV(`Mill KW`)
                FROM cement
            ), 3))
    ) AS skewness_mill_kw,
    (
        SELECT
            SUM(POWER(`Mill KW` - (
                SELECT AVG(`Mill KW`)
                FROM cement
            ), 4)) / (COUNT(*) * POWER((
                SELECT VARIANCE(`Mill KW`)
                FROM cement
            ), 2))
    ) AS kurtosis_mill_kw
FROM
    cement;

-- ------------------------------------------------------------------------------------------------
--  4. Handling Outliers using Interquartile Range (IQR) Method
-- ------------------------------------------------------------------------------------------------
-- NOTE: This query identifies outliers but DOES NOT remove them.

WITH Ranked AS (
    SELECT
        `Date & Time`,
        `Mill TPH`,
        `Clinker TPH`,
        `Mill KW`,
        `Sep RPM`,
        `residue`,
        ROW_NUMBER() OVER (ORDER BY `Mill TPH`) AS mill_rank,
        ROW_NUMBER() OVER (ORDER BY `Clinker TPH`) AS clinker_rank,
        COUNT(*) OVER () AS total_rows
    FROM
        cement
), Quartiles AS (
    SELECT
        (
            SELECT `Mill TPH`
            FROM Ranked
            WHERE mill_rank = FLOOR(0.25 * total_rows)
            LIMIT 1
        ) AS Q1_Mill_TPH,
        (
            SELECT `Mill TPH`
            FROM Ranked
            WHERE mill_rank = FLOOR(0.75 * total_rows)
            LIMIT 1
        ) AS Q3_Mill_TPH,
        (
            SELECT `Clinker TPH`
            FROM Ranked
            WHERE clinker_rank = FLOOR(0.25 * total_rows)
            LIMIT 1
        ) AS Q1_Clinker_TPH,
        (
            SELECT `Clinker TPH`
            FROM Ranked
            WHERE clinker_rank = FLOOR(0.75 * total_rows)
            LIMIT 1
        ) AS Q3_Clinker_TPH
    FROM
        Ranked
)
SELECT
    c.`Date & Time`,
    c.`Mill TPH`,
    c.`Clinker TPH`,
    c.`Mill KW`,
    c.`Sep RPM`,
    c.`residue`
FROM
    cement c
    JOIN Quartiles q ON 1 = 1  -- Ensures the subquery returns a single row
WHERE
    c.`Mill TPH` < (q.Q1_Mill_TPH - 1.5 * (q.Q3_Mill_TPH - q.Q1_Mill_TPH))
    OR c.`Mill TPH` > (q.Q3_Mill_TPH + 1.5 * (q.Q3_Mill_TPH - q.Q1_Mill_TPH))
    OR c.`Clinker TPH` < (q.Q1_Clinker_TPH - 1.5 * (q.Q3_Clinker_TPH - q.Q1_Clinker_TPH))
    OR c.`Clinker TPH` > (q.Q3_Clinker_TPH + 1.5 * (q.Q3_Clinker_TPH - q.Q1_Clinker_TPH))
ORDER BY
    c.`Date & Time` DESC;

-- ------------------------------------------------------------------------------------------------
--  5. Performance & Efficiency Insights
-- ------------------------------------------------------------------------------------------------

-- Correlation Between Mill Power & Production
SELECT
    (
        SUM((`Mill TPH` - temp.avg_mill_tph) * (`Mill KW` - temp.avg_mill_kw)) / (SQRT(SUM(POW(`Mill TPH` - temp.avg_mill_tph, 2))) * SQRT(SUM(POW(`Mill KW` - temp.avg_mill_kw, 2))))
    ) AS correlation_mill_tph_kw
FROM
    cement,
    (
        SELECT
            AVG(`Mill TPH`) AS avg_mill_tph,
            AVG(`Mill KW`) AS avg_mill_kw
        FROM
            cement
    ) AS temp;

-- Impact of Temperature on Performance
SELECT
    AVG(`Mill I/L Temp`) AS avg_mill_il_temp,
    AVG(`Mill O/L Temp`) AS avg_mill_ol_temp,
    AVG(`mill tph`) AS avg_mill_tph
FROM
    cement;

-- Separator RPM vs. Mill Performance
SELECT
    `sep rpm`,
    AVG(`mill tph`) AS avg_mill_tph
FROM
    cement
GROUP BY
    `sep rpm`;

-- Mill Fan Power vs. Production Rate
SELECT
    `Mill Vent Fan KW`,
    AVG(`mill TPH`) AS avg_mill_tph
FROM
    cement
GROUP BY
    `Mill Vent Fan KW`;

-- Residue vs. Production
SELECT
    `residue`,
    AVG(`mill TPH`) AS avg_mill_tph
FROM
    cement
GROUP BY
    `residue`;

-- ------------------------------------------------------------------------------------------------
--  6. Real-Time Monitoring Views
-- ------------------------------------------------------------------------------------------------

-- Create a Live Data View
CREATE OR REPLACE VIEW cement_dashboard AS
SELECT
    `Date & Time`,
    `mill TPH`,
    `mill kw`,
    `Sep RPM`,
    `residue`,
    `reject`,
    `Mill I/L Temp`,
    `Mill O/L Temp`
FROM
    cement
ORDER BY
    `Date & Time` DESC;

-- Identify Underperforming Periods
SELECT
    `Date & Time`,
    `mill TPH`,
    `mill kw`
FROM
    cement
WHERE
    `mill TPH` < (
        SELECT
            AVG(`mill TPH`)
        FROM
            cement
    ) * 0.8
ORDER BY
    `Date & Time` DESC;

-- Power Consumption Extremes
SELECT
    MIN(`mill kw`) AS min_power,
    MAX(`mill kw`) AS max_power
FROM
    cement;

-- ------------------------------------------------------------------------------------------------
--  7. Alerts & Anomalies
-- ------------------------------------------------------------------------------------------------

-- Reject Rate Alert
SELECT
    `Date & Time`,
    `reject`
FROM
    cement
WHERE
    `reject` > (
        SELECT
            AVG(`reject`)
        FROM
            cement
    ) * 1.5;

-- High Temperature Alert
SELECT
    `Date & Time`,
    `Mill I/L Temp`,
    `Mill O/L Temp`
FROM
    cement
WHERE
    `Mill O/L Temp` > 100;

-- Separator Inefficiency Alert
SELECT
    `Date & Time`,
    `Sep RPM`,
    `Sep KW`
FROM
    cement
WHERE
    `Sep KW` > (
        SELECT
            AVG(`Sep KW`)
        FROM
            cement
    ) * 1.3;

-- ------------------------------------------------------------------------------------------------
--  8. Predictive Maintenance Queries
-- ------------------------------------------------------------------------------------------------

-- Predictive Maintenance Queries
SELECT
    `Date & Time`,
    `Sep RPM`,
    `Mill Vent Fan KW`,
    `Mill Vent Fan RPM`,
    `Sep KW`
FROM
    cement
WHERE
    `Mill Vent Fan KW` > (
        SELECT
            AVG(`Mill Vent Fan KW`)
        FROM
            cement
    ) * 1.2
    OR `Sep KW` > (
        SELECT
            AVG(`Sep KW`)
        FROM
            cement
    ) * 1.2
ORDER BY
    `Date & Time` DESC;

-- (If fan power or separator KW increases over time, it might indicate wear and tear, requiring maintenance.)

-- Identify Unusual Power Consumption Spikes
SELECT
    `Date & Time`,
    `mill kw`,
    `Sep KW`,
    `CA Fan KW`
FROM
    cement
WHERE
    `mill kw` > (
        SELECT
            AVG(`mill kw`)
        FROM
            cement
    ) * 1.2
    OR `Sep KW` > (
        SELECT
            AVG(`Sep KW`)
        FROM
            cement
    ) * 1.2
    OR `CA Fan KW` > (
        SELECT
            AVG(`CA Fan KW`)
        FROM
            cement
    ) * 1.2
ORDER BY
    `Date & Time` DESC;

-- (Sudden jumps in KW usage could indicate motor degradation, load imbalance, or mechanical inefficiencies.)

-- Predictive Fan Failure (RPM & KW Correlation)
SELECT
    `Mill Vent Fan RPM`,
    `Mill Vent Fan KW`,
    COUNT(*) AS occurrences
FROM
    cement
WHERE
    `Mill Vent Fan RPM` IS NOT NULL
    AND `Mill Vent Fan KW` IS NOT NULL
    AND `Mill Vent Fan RPM` < (
        SELECT
            AVG(`Mill Vent Fan RPM`)
        FROM
            cement
        WHERE
            `Mill Vent Fan RPM` IS NOT NULL
    ) * 0.85
    AND `Mill Vent Fan KW` > (
        SELECT
            AVG(`Mill Vent Fan KW`)
        FROM
            cement
        WHERE
            `Mill Vent Fan KW` IS NOT NULL
    ) * 1.1
GROUP BY
    `Mill Vent Fan RPM`,
    `Mill Vent Fan KW`
ORDER BY
    occurrences DESC;

-- (A fan consuming high power with lower RPM may indicate belt slippage or mechanical failure.)

-- Detect Separator Wear & Inefficiency
SELECT
    MIN(`Sep RPM`) AS min_sep_rpm,
    MAX(`Sep RPM`) AS max_sep_rpm,
    MIN(`residue`) AS min_residue,
    MAX(`residue`) AS max_residue
FROM
    cement;

-- (If MIN(Sep RPM) > (AVG(Sep RPM) * 0.8), then no values can satisfy the condition, If MAX(residue) < (AVG(residue) * 1.2), then no values can satisfy the condition.)
-- (Sep RPM must be less than 952.12 * 0.8 = 761.69, Residue must be greater than 15.19 * 1.2 = 18.23)
SELECT
    `Date & Time`,
    `Sep RPM`,
    `residue`
FROM
    cement
WHERE
    `Sep RPM` < (
        SELECT
            AVG(`Sep RPM`)
        FROM
            cement
    ) * 0.95  -- Changed from 0.8 to 0.95
    AND `residue` > (
        SELECT
            AVG(`residue`)
        FROM
            cement
    ) * 1.1  -- Changed from 1.2 to 1.1
ORDER BY
    `Date & Time` DESC;

-- (If the separator RPM is low and residue is high, it may indicate separator blade wear.)

-- Predict Cement Quality Degradation
SELECT
    `Date & Time`,
    AVG(`residue`) OVER (
        ORDER BY
            `Date & Time` ROWS BETWEEN 10 PRECEDING AND CURRENT ROW
    ) AS rolling_avg_residue
FROM
    cement
ORDER BY
    `Date & Time` DESC;

-- (A gradual increase in rolling average residue indicates a decline in cement fineness, requiring separator adjustment.)

-- Predictive Maintenance Alerts Based on Running Hours
SELECT
    `mill kw`,
    COUNT(*) AS running_hours,
    CASE
        WHEN COUNT(*) > 100 THEN 'Maintenance Required'
        ELSE 'Running Normally'
    END AS maintenance_status
FROM
    cement
GROUP BY
    `mill kw`;

-- (If equipment has run continuously for over 100 hours, schedule maintenance.)

-- Temperature-Based Equipment Failure Prediction
SELECT
    `Date & Time`,
    `Mill O/L Temp`,
    `Mill I/L Temp`
FROM
    cement
WHERE
    `Mill O/L Temp` > (
        SELECT
            AVG(`Mill O/L Temp`)
        FROM
            cement
    ) * 1.3
ORDER BY
    `Date & Time` DESC;

-- (A 30% rise in outlet temperature suggests bearing wear, lubrication issues, or heat dissipation failure)

-- ------------------------------------------------------------------------------------------------
--  9. Trend Forecasting Queries
-- ------------------------------------------------------------------------------------------------

-- Monthly Trend of Production Efficiency
SELECT
    DATE_FORMAT(STR_TO_DATE(`Date & Time`, '%m/%d/%Y %H:%i'), '%Y-%m') AS month,
    AVG(`Mill TPH`) AS avg_production,
    AVG(`mill KW`) AS avg_power
FROM
    cement
WHERE
    `Date & Time` IS NOT NULL
GROUP BY
    DATE_FORMAT(STR_TO_DATE(`Date & Time`, '%m/%d/%Y %H:%i'), '%Y-%m')
ORDER BY
    month DESC;

-- (Helps track monthly production efficiency and power consumption trends.)

-- Long-Term Separator Performance Trend
SELECT
    DATE_FORMAT(STR_TO_DATE(`Date & Time`, '%m/%d/%Y %H:%i'), '%Y-%m') AS month,
    AVG(`Sep RPM`) AS avg_sep_rpm,
    AVG(`Residue`) AS avg_residue
FROM
    cement
WHERE
    `Date & Time` IS NOT NULL
GROUP BY
    DATE_FORMAT(STR_TO_DATE(`Date & Time`, '%m/%d/%Y %H:%i'), '%Y-%m')
ORDER BY
    month DESC;

-- (Shows if separator performance is degrading over time.)

-- Trend in Energy Consumption vs. Output
SELECT
    DATE_FORMAT(STR_TO_DATE(`Date & Time`, '%m/%d/%Y %H:%i'), '%Y-%m') AS month,
    SUM(`mill KW`) / SUM(`mill TPH`) AS energy_per_ton
FROM
    cement
GROUP BY
    DATE_FORMAT(STR_TO_DATE(`Date & Time`, '%m/%d/%Y %H:%i'), '%Y-%m')
ORDER BY
    month DESC;

-- (Helps identify rising energy consumption per ton—a sign of inefficiencies.)

-- Forecast Future Cement Mill Efficiency
SELECT
    DATE_FORMAT(STR_TO_DATE(`Date & Time`, '%m/%d/%Y %H:%i'), '%Y-%m') AS month,
    AVG(`mill TPH`) AS avg_production,
    LAG(AVG(`mill TPH`), 1) OVER (
        ORDER BY
            DATE_FORMAT(STR_TO_DATE(`Date & Time`, '%m/%d/%Y %H:%i'), '%Y-%m')
    ) AS prev_month_production,
    (
        AVG(`mill TPH`) - LAG(AVG(`mill TPH`), 1) OVER (
            ORDER BY
                DATE_FORMAT(STR_TO_DATE(`Date & Time`, '%m/%d/%Y %H:%i'), '%Y-%m')
        )
    ) / LAG(AVG(`mill TPH`), 1) OVER (
        ORDER BY
            DATE_FORMAT(STR_TO_DATE(`Date & Time`, '%m/%d/%Y %H:%i'), '%Y-%m')
    ) * 100 AS production_growth
FROM
    cement
GROUP BY
    DATE_FORMAT(STR_TO_DATE(`Date & Time`, '%m/%d/%Y %H:%i'), '%Y-%m')
ORDER BY
    month DESC;

-- (Provides a month-over-month production trend and growth percentage.)
