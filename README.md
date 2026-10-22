Built a PostgreSQL-based DBT fund monitoring system combining public aggregate
DBT reports with synthetic operational payment records. Designed normalized reference and operational tables, loaded
data through staging workflows, implemented SQL reconciliation checks, and developed rule-based screening for
potential duplicate payments, delayed payouts and amount mismatches using Python and PostgreSQL.


Integrated public DBT datasets: Worked with state-wise, district-wise and scheme-wise Direct Benefit Transfer (DBT) data from the Government of India’s DBT Bharat portal to analyze subsidy disbursement patterns, transaction volumes and public fund transfers.

Built a PostgreSQL data staging layer: Designed the staging schema and structured raw tables for state-level, district-level and scheme-level data, maintaining consistent column names and data types for downstream analysis.

Automated Excel data ingestion with Python: Used Pandas and Psycopg2 to load scheme-wise Excel files into PostgreSQL, assign financial-year labels programmatically, standardize column names and convert expenditure values into numeric format.

Performed data quality checks: Prepared validation queries to identify missing scheme names, ministry details, benefit types and expenditure values, supporting more reliable analysis of government disbursement records.

Analyzed fund transfers across administrative levels: Structured data to compare DBT transfers and transaction counts across states and districts, and examine scheme-level expenditure by ministry, scheme and financial year.

Designed an anomaly-detection workflow: Planned SQL-based checks for duplicate transactions, delayed payments and unusual disbursement patterns using operational transaction records. Detailed transaction-level anomaly detection requires a separate operational dataset, as the public DBT aggregates do not contain individual beneficiary payment records.

Prepared a foundation for financial monitoring: Organized the data pipeline for future reconciliation, exception reporting and analytical views, with the aim of supporting public-fund monitoring and evidence-based decision-making.
Data sources and years used
Dataset	Source	Coverage
State-wise DBT data	Government of India — DBT Bharat portal	FY 2019–2023, based on the downloaded dataset
District-wise DBT data	DBT Bharat portal	FY 2019–20 and FY 2020–21
Scheme-wise fund transfer data	DBT Bharat portal, downloaded as Excel files	FY 2019–20 and FY 2020–21

Limitations
- Aggregated public data: The datasets report transfers and transaction counts at administrative or scheme level, rather than individual beneficiary-level payment records.
- Limited historical coverage: District-wise and scheme-wise datasets cover only two financial years, restricting longer-term trend analysis.
- No beneficiary-level audit trail: Duplicate individual payments, actual payout delays and beneficiary-level anomalies cannot be conclusively detected using the public aggregates alone.
- Anomaly detection scope: Transaction-level detection requires a separate operational dataset. If synthetic transactions are used, they must be clearly identified as simulated rather than official government records.
- Data quality considerations: Missing values, inconsistent source formatting and differences in reporting granularity may affect comparisons. Financial amounts and record counts should be validated before drawing conclusions.
- Association is not causation: Differences in transfer amounts or transaction volumes do not, by themselves, establish fraud, irregularity or poor scheme performance.
Key concepts and technologies used

Technologies
- PostgreSQL — relational database, schemas, staging tables, SQL queries and data validation.
- Python — data ingestion and preprocessing.
- Pandas — Excel processing, column standardization, missing-value handling and numeric conversion.
- Psycopg2 — Python–PostgreSQL connectivity and batch inserts.
- Excel / XLSX — source data format.
Key concepts
- ETL (Extract, Transform, Load)
- Data staging and schema design
- Data cleaning and type conversion
- Financial-year-based data organization
- SQL aggregation, filtering and data quality checks
- Public financial management and subsidy disbursement analysis
- Anomaly detection, reconciliation and exception reporting — with transaction-level detection dependent on suitable operational data.
Resume tip: Describe the project as a DBT disbursement analytics and anomaly-detection pipeline and distinguish implemented functionality from planned functionality. That keeps the project credible and makes your technical contribution clear.
