-- =====================================================================
-- CREDIT RISK & LOAN DEFAULT ANALYSIS
-- Day 1 & 2: Setup | Cleaning | Descriptive Stats | EDA | Business Insights
-- =====================================================================

-- =====================================================================
-- STEP 0: DATABASE & TABLE SETUP
-- =====================================================================

CREATE DATABASE IF NOT EXISTS credit_risk_project;
USE credit_risk_project;

DROP TABLE IF EXISTS loans_raw;
CREATE TABLE loans_raw (
    person_age                  INT,
    person_income               INT,
    person_home_ownership       VARCHAR(20),
    person_emp_length           FLOAT,
    loan_intent                 VARCHAR(30),
    loan_grade                  VARCHAR(5),
    loan_amnt                   INT,
    loan_int_rate                FLOAT,
    loan_status                 INT,
    loan_percent_income         FLOAT,
    cb_person_default_on_file   VARCHAR(5),
    cb_person_cred_hist_length  INT
);

-- Staging table (all text) — avoids import errors from blank cells
DROP TABLE IF EXISTS loans_staging;
CREATE TABLE loans_staging (
    person_age                  VARCHAR(20),
    person_income               VARCHAR(20),
    person_home_ownership       VARCHAR(20),
    person_emp_length           VARCHAR(20),
    loan_intent                 VARCHAR(30),
    loan_grade                  VARCHAR(5),
    loan_amnt                   VARCHAR(20),
    loan_int_rate                VARCHAR(20),
    loan_status                 VARCHAR(20),
    loan_percent_income         VARCHAR(20),
    cb_person_default_on_file   VARCHAR(5),
    cb_person_cred_hist_length  VARCHAR(20)
);

-- Load CSV into staging (update path to match your machine)
SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'C:/Users/91970/Downloads/credit_risk_dataset.csv'
INTO TABLE loans_staging
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM loans_staging;   -- expect 32581

-- Transfer staging -> raw with proper types and real NULLs
TRUNCATE TABLE loans_raw;

INSERT INTO loans_raw
SELECT
    CAST(person_age AS UNSIGNED),
    CAST(person_income AS UNSIGNED),
    person_home_ownership,
    CASE WHEN person_emp_length = '' THEN NULL ELSE CAST(person_emp_length AS DECIMAL(10,2)) END,
    loan_intent,
    loan_grade,
    CAST(loan_amnt AS UNSIGNED),
    CASE WHEN loan_int_rate = '' THEN NULL ELSE CAST(loan_int_rate AS DECIMAL(10,2)) END,
    CAST(loan_status AS UNSIGNED),
    CAST(loan_percent_income AS DECIMAL(10,4)),
    cb_person_default_on_file,
    CAST(cb_person_cred_hist_length AS UNSIGNED)
FROM loans_staging;

SELECT COUNT(*) FROM loans_raw;   -- expect 32581


-- =====================================================================
-- STEP 1: DATA AUDIT
-- =====================================================================

-- Missing values
SELECT
    SUM(CASE WHEN person_age IS NULL THEN 1 ELSE 0 END)                 AS null_age,
    SUM(CASE WHEN person_income IS NULL THEN 1 ELSE 0 END)              AS null_income,
    SUM(CASE WHEN person_emp_length IS NULL THEN 1 ELSE 0 END)          AS null_emp_length,
    SUM(CASE WHEN loan_int_rate IS NULL THEN 1 ELSE 0 END)              AS null_int_rate,
    SUM(CASE WHEN cb_person_default_on_file IS NULL THEN 1 ELSE 0 END)  AS null_default_on_file
FROM loans_raw;
-- Result: null_emp_length = 895, null_int_rate = 3116, others = 0

-- Duplicate rows
SELECT person_age, person_income, person_home_ownership, person_emp_length,
       loan_intent, loan_grade, loan_amnt, loan_int_rate, loan_status,
       loan_percent_income, cb_person_default_on_file, cb_person_cred_hist_length,
       COUNT(*) AS occurrences
FROM loans_raw
GROUP BY person_age, person_income, person_home_ownership, person_emp_length,
         loan_intent, loan_grade, loan_amnt, loan_int_rate, loan_status,
         loan_percent_income, cb_person_default_on_file, cb_person_cred_hist_length
HAVING COUNT(*) > 1;
-- Result: 165 duplicate rows

-- Impossible values
SELECT COUNT(*) AS impossible_ages FROM loans_raw WHERE person_age > 100;          -- Result: 5
SELECT COUNT(*) AS impossible_emp_length FROM loans_raw WHERE person_emp_length > 60; -- Result: 2


-- =====================================================================
-- STEP 2: DATA CLEANING
-- =====================================================================

DROP TABLE IF EXISTS loans_cleaned;
CREATE TABLE loans_cleaned AS
SELECT DISTINCT *
FROM loans_raw
WHERE person_age <= 100
  AND (person_emp_length <= 60 OR person_emp_length IS NULL);

SELECT COUNT(*) AS rows_after_cleaning FROM loans_cleaned;   -- Result: 32409

SET SQL_SAFE_UPDATES = 0;

-- Fill missing loan_int_rate using average rate per loan grade
UPDATE loans_cleaned lc
JOIN (
    SELECT loan_grade, AVG(loan_int_rate) AS avg_rate
    FROM loans_cleaned
    WHERE loan_int_rate IS NOT NULL
    GROUP BY loan_grade
) g ON lc.loan_grade = g.loan_grade
SET lc.loan_int_rate = ROUND(g.avg_rate, 2)
WHERE lc.loan_int_rate IS NULL;
-- Result: 3094 rows filled

-- Fill missing person_emp_length using overall average
UPDATE loans_cleaned
SET person_emp_length = (
    SELECT avg_emp FROM (
        SELECT ROUND(AVG(person_emp_length), 1) AS avg_emp
        FROM loans_cleaned
        WHERE person_emp_length IS NOT NULL
    ) x
)
WHERE person_emp_length IS NULL;
-- Result: 887 rows filled

-- Verify — both should be 0
SELECT
    SUM(CASE WHEN loan_int_rate IS NULL THEN 1 ELSE 0 END) AS remaining_null_rate,
    SUM(CASE WHEN person_emp_length IS NULL THEN 1 ELSE 0 END) AS remaining_null_emp
FROM loans_cleaned;


-- =====================================================================
-- STEP 3: DESCRIPTIVE STATISTICS
-- =====================================================================

SELECT
    ROUND(AVG(person_age),1)     AS avg_age,
    MIN(person_age)              AS min_age,
    MAX(person_age)              AS max_age,
    ROUND(AVG(person_income))    AS avg_income,
    MIN(person_income)           AS min_income,
    MAX(person_income)           AS max_income,
    ROUND(AVG(loan_amnt))        AS avg_loan_amount,
    MIN(loan_amnt)               AS min_loan_amount,
    MAX(loan_amnt)               AS max_loan_amount,
    ROUND(AVG(loan_int_rate),2)  AS avg_interest_rate
FROM loans_cleaned;


-- =====================================================================
-- STEP 4: EXPLORATORY DATA ANALYSIS (EDA)
-- =====================================================================

-- 4a. Overall default rate
SELECT
    SUM(loan_status) AS total_defaults,
    COUNT(*) AS total_loans,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM loans_cleaned;
-- Result: 21.87% overall default rate

-- 4b. Default rate by loan grade
SELECT
    loan_grade,
    COUNT(*) AS total_loans,
    SUM(loan_status) AS defaults,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM loans_cleaned
GROUP BY loan_grade
ORDER BY loan_grade;

-- 4c. Default rate by loan purpose
SELECT
    loan_intent,
    COUNT(*) AS total_loans,
    SUM(loan_status) AS defaults,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM loans_cleaned
GROUP BY loan_intent
ORDER BY default_rate_pct DESC;

-- 4d. Default rate by home ownership
SELECT
    person_home_ownership,
    COUNT(*) AS total_loans,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM loans_cleaned
GROUP BY person_home_ownership
ORDER BY default_rate_pct DESC;

-- 4e. Default rate by income bracket
SELECT
    CASE
        WHEN person_income < 25000 THEN 'Under 25K'
        WHEN person_income BETWEEN 25000 AND 50000 THEN '25K-50K'
        WHEN person_income BETWEEN 50001 AND 75000 THEN '50K-75K'
        WHEN person_income BETWEEN 75001 AND 100000 THEN '75K-100K'
        ELSE 'Above 100K'
    END AS income_bracket,
    COUNT(*) AS total_loans,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM loans_cleaned
GROUP BY income_bracket
ORDER BY MIN(person_income);

-- 4f. Default rate by prior default history
SELECT
    cb_person_default_on_file,
    COUNT(*) AS total_loans,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM loans_cleaned
GROUP BY cb_person_default_on_file;

-- 4g. Default rate by debt burden (loan as % of income)
SELECT
    CASE
        WHEN loan_percent_income < 0.1 THEN 'Under 10%'
        WHEN loan_percent_income BETWEEN 0.1 AND 0.2 THEN '10-20%'
        WHEN loan_percent_income BETWEEN 0.21 AND 0.3 THEN '21-30%'
        ELSE 'Above 30%'
    END AS debt_burden_bracket,
    COUNT(*) AS total_loans,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM loans_cleaned
GROUP BY debt_burden_bracket
ORDER BY MIN(loan_percent_income);

-- 4h. Default rate by age group
SELECT
    CASE
        WHEN person_age < 25 THEN 'Under 25'
        WHEN person_age BETWEEN 25 AND 34 THEN '25-34'
        WHEN person_age BETWEEN 35 AND 44 THEN '35-44'
        WHEN person_age BETWEEN 45 AND 54 THEN '45-54'
        ELSE '55+'
    END AS age_group,
    COUNT(*) AS total_loans,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM loans_cleaned
GROUP BY age_group
ORDER BY MIN(person_age);
