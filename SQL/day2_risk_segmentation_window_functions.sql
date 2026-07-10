-- =====================================================================
-- CREDIT RISK & LOAN DEFAULT ANALYSIS — DAY 2
-- Risk Segmentation | Segmentation Validation | Window Functions
-- =====================================================================
-- Builds on loans_cleaned (from Day 1). Run day1_day2_analysis.sql first
-- if starting fresh.
-- =====================================================================


-- =====================================================================
-- STEP 1: RISK SEGMENTATION
-- =====================================================================
-- Combines loan_grade and debt-to-income ratio (loan_percent_income)
-- into a single Low/Medium/High risk label. Conditions are ordered
-- WORST-CASE FIRST so a single severe risk factor (e.g. a very high
-- debt burden) correctly overrides a milder one, instead of being
-- masked by a looser OR condition lower down.
-- =====================================================================

DROP TABLE IF EXISTS loans_risk_segmented;

CREATE TABLE loans_risk_segmented AS
SELECT
    *,
    CASE
        WHEN loan_grade IN ('D','E','F','G') OR loan_percent_income > 0.35 THEN 'High Risk'
        WHEN loan_grade = 'C' OR loan_percent_income BETWEEN 0.20 AND 0.35 THEN 'Medium Risk'
        WHEN loan_grade IN ('A','B') AND loan_percent_income <= 0.20 THEN 'Low Risk'
        ELSE 'Medium Risk'
    END AS risk_segment
FROM loans_cleaned;

SELECT COUNT(*) FROM loans_risk_segmented;   -- expect 32409


-- =====================================================================
-- STEP 2: SEGMENTATION VALIDATION
-- =====================================================================
-- The real test of a risk model: does default rate actually differ
-- meaningfully across segments? A wide spread = a useful model.
-- =====================================================================

SELECT
    risk_segment,
    COUNT(*) AS total_loans,
    SUM(loan_status) AS defaults,
    ROUND(SUM(loan_status) * 100.0 / COUNT(*), 2) AS default_rate_pct
FROM loans_risk_segmented
GROUP BY risk_segment
ORDER BY default_rate_pct DESC;

-- Result:
-- High Risk    | 6,608 loans  | 4,160 defaults | 62.95%
-- Medium Risk  | 11,366 loans | 2,083 defaults | 18.33%
-- Low Risk     | 14,435 loans | 845 defaults   | 5.85%
-- ~11x spread between High and Low Risk confirms the segmentation
-- is genuinely predictive, not an arbitrary label.


-- =====================================================================
-- STEP 3: WINDOW FUNCTIONS — RANK() vs DENSE_RANK()
-- =====================================================================
-- Both assign a rank based on ORDER BY, but handle ties differently:
--   RANK()       -> ties share a rank, next rank SKIPS ahead
--   DENSE_RANK() -> ties share a rank, next rank has NO gap
-- =====================================================================

SELECT
    person_age,
    loan_grade,
    loan_percent_income,
    risk_segment,
    RANK()       OVER (ORDER BY loan_percent_income DESC) AS rank_with_gaps,
    DENSE_RANK() OVER (ORDER BY loan_percent_income DESC) AS dense_rank_no_gaps
FROM loans_risk_segmented
WHERE risk_segment = 'High Risk'
LIMIT 20;


-- =====================================================================
-- STEP 4: PARTITION BY — RANKING WITHIN GROUPS
-- =====================================================================
-- Without PARTITION BY, a global rank would always put High Risk
-- borrowers at the top. PARTITION BY restarts the ranking count at 1
-- separately for each risk_segment, surfacing the riskiest individual
-- WITHIN each group.
-- =====================================================================

SELECT
    person_age,
    loan_grade,
    loan_percent_income,
    risk_segment,
    RANK() OVER (PARTITION BY risk_segment ORDER BY loan_percent_income DESC) AS rank_within_segment
FROM loans_risk_segmented
ORDER BY risk_segment, rank_within_segment;


-- =====================================================================
-- STEP 5: TOP 3 RISKIEST BORROWERS PER SEGMENT
-- =====================================================================
-- IMPORTANT LESSON: using RANK() here initially returned 788 rows
-- instead of 9, because hundreds of borrowers shared the exact same
-- loan_percent_income at each segment's boundary (0.19, 0.35, 0.83),
-- so RANK() assigned all of them rank = 1.
--
-- FIX: ROW_NUMBER() never ties — it assigns strictly increasing
-- numbers (1, 2, 3...) even among identical values, guaranteeing
-- exactly 3 rows per segment regardless of duplicates.
-- =====================================================================

-- The version that caused the 788-row issue (kept here for reference):
-- SELECT * FROM (
--     SELECT person_age, loan_grade, loan_percent_income, risk_segment,
--            RANK() OVER (PARTITION BY risk_segment ORDER BY loan_percent_income DESC) AS rank_within_segment
--     FROM loans_risk_segmented
-- ) ranked
-- WHERE rank_within_segment <= 3;

-- The corrected version using ROW_NUMBER():
SELECT * FROM (
    SELECT
        person_age,
        person_income,
        loan_grade,
        loan_percent_income,
        risk_segment,
        ROW_NUMBER() OVER (PARTITION BY risk_segment ORDER BY loan_percent_income DESC) AS row_num
    FROM loans_risk_segmented
) ranked
WHERE row_num <= 3
ORDER BY risk_segment, row_num;


-- =====================================================================
-- STEP 6: RUNNING TOTALS (CUMULATIVE DEFAULT COUNT)
-- =====================================================================
-- Answers: "If we only approved the N riskiest loans by debt burden,
-- how many defaults would we have absorbed?" — useful for setting
-- data-driven approval cutoffs.
-- =====================================================================

SELECT
    person_age,
    loan_grade,
    loan_percent_income,
    loan_status,
    SUM(loan_status) OVER (
        ORDER BY loan_percent_income DESC
        ROWS UNBOUNDED PRECEDING
    ) AS running_default_count
FROM loans_risk_segmented
WHERE risk_segment = 'High Risk'
ORDER BY loan_percent_income DESC
LIMIT 20;

-- =====================================================================
-- END OF DAY 2 SQL
-- =====================================================================
