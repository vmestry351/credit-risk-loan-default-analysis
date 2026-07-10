# Credit Risk & Loan Default Analysis

SQL-based analysis of 32,500+ loan records to identify the key drivers of borrower default, with the goal of supporting smarter lending decisions.

## 📌 Project Overview

A lending institution wants to minimize loan defaults while maximizing approvals for reliable borrowers. This project analyzes historical loan data to answer:

- Why do customers default?
- Who is high risk?
- What characteristics increase default probability?
- How should the bank improve lending?

**Tools used:** MySQL (data cleaning, analysis) · Excel/Word (documentation)

## 📁 Repository Structure

```
credit-risk-loan-default-analysis/
├── Data/
│   ├── Raw_Data.csv          # Original, unedited dataset (32,581 rows)
│   └── Cleaned_Data.csv      # Cleaned dataset used for analysis (32,409 rows)
├── SQL/
│   ├── day1_day2_analysis.sql                        # Setup, cleaning, EDA
│   └── day2_risk_segmentation_window_functions.sql   # Risk segmentation, window functions
├── Reports/
│   ├── Business_Insights.docx # Day 1 — 10 business insights with evidence & recommendations
│   ├── Data_Audit.docx        # Data dictionary, audit findings, cleaning log
│   └── Day2_Summary.docx      # Day 2 — risk segmentation & window function summary
└── README.md
```

## 🧹 Data Cleaning Summary

| Issue | Found | Action Taken |
|---|---|---|
| Duplicate rows | 165 | Removed |
| Impossible ages (>100) | 5 | Removed |
| Impossible employment length (>60 yrs) | 2 | Removed |
| Missing interest rate | 3,116 | Filled with grade-based average |
| Missing employment length | 895 | Filled with column average |

**Result:** 32,581 raw rows → **32,409 clean rows**, zero missing values.

## 🔍 Key Findings

| Factor | Highest-Risk Segment | Default Rate |
|---|---|---|
| Loan Grade | Grade G | 98.44% |
| Debt Burden | Loan > 30% of income | 50.73% |
| Income | Under ₹25K | 54.61% |
| Home Ownership | Renting | 31.61% |
| Loan Purpose | Debt Consolidation | 28.68% |
| Prior Default History | Yes (on file) | 37.86% |
| Age | Not a meaningful predictor | ~20–25% across all groups |

**Overall portfolio default rate: 21.87%** (7,088 of 32,409 loans)

### Top Insights

1. **Loan grade is the strongest single predictor** — default risk jumps sharply from Grade C (20.76%) to Grade D (59.05%), suggesting the bank's grading cutoffs may need review.
2. **Debt-to-income ratio above 30% roughly doubles default risk** compared to the 21–30% band — a strong candidate for a hard lending threshold.
3. **Renters default over 4x more often than outright homeowners** (31.61% vs 7.49%).
4. **Age shows almost no correlation with default** — a common assumption this analysis disproves.

Full write-up with evidence and business recommendations: [`Reports/Business_Insights.docx`](./Reports/Business_Insights.docx)

### Day 2 — Risk Segmentation Results

A multi-factor risk model (combining loan grade + debt-to-income ratio) was built and validated against actual default outcomes:

| Risk Segment | Total Loans | Default Rate |
|---|---|---|
| High Risk | 6,608 | 62.95% |
| Medium Risk | 11,366 | 18.33% |
| Low Risk | 14,435 | 5.85% |

An ~11x spread between High and Low Risk confirms this segmentation is genuinely predictive, not arbitrary. Full write-up: [`Reports/Day2_Summary.docx`](./Reports/Day2_Summary.docx)

## 🛠️ Methodology

1. **Business Understanding** — defined stakeholders, objectives, and success criteria.
2. **Data Audit** — profiled the raw dataset for nulls, duplicates, and invalid values using SQL.
3. **Data Cleaning** — built a reproducible SQL pipeline (staging → typed table → cleaned table).
4. **Exploratory Data Analysis** — queried default rate across 8 dimensions (grade, purpose, income, ownership, debt burden, age, credit history).
5. **Business Insights** — translated each finding into an evidence-backed, actionable recommendation.
6. **Risk Segmentation & Window Functions** — combined multiple risk factors into a single Low/Medium/High model using layered `CASE WHEN` logic, then used `RANK()`, `ROW_NUMBER()`, `PARTITION BY`, and running totals to rank and analyze borrowers within each segment.

Full SQL pipeline: [`SQL/day1_day2_analysis.sql`](./SQL/day1_day2_analysis.sql) · [`SQL/day2_risk_segmentation_window_functions.sql`](./SQL/day2_risk_segmentation_window_functions.sql)

## 📊 Dataset

Source: [Credit Risk Dataset, Kaggle](https://www.kaggle.com/datasets/laotse/credit-risk-dataset) — 32,581 loan applicants with demographic, financial, and loan-specific attributes.

## 🚀 Next Steps

- [ ] Interactive Tableau dashboard
- [ ] Executive summary report

---

**Author:** Vinayak Mestry
