-- Run as an administrator, where permitted.
--CREATE ROLE dbt_apostgresnalyst LOGIN PASSWORD 'CHANGE_THIS_PASSWORD';
-- DROP ROLE IF EXISTS dbt_apostgresnalyst;

-- Run as an administrator, where permitted.

CREATE ROLE dbt_analyst LOGIN PASSWORD 'CHANGE_THIS_PASSWORD'

GRANT CONNECT ON DATABASE dbt_monitoring TO dbt_analyst;


--AFTER connecting to dbt_monitoring;
CREATE SCHEMA IF NOT EXISTS reference;
CREATE SCHEMA IF NOT EXISTS ops;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS analytics;

GRANT USAGE ON SCHEMA reference, ops, audit, analytics TO dbt_analyst;

GRANT CREATE ON SCHEMA reference, ops, audit, analytics TO dbt_analyst;


--Creating reference tables for a reusable stable information 

CREATE TABLE reference.states (
 state_id BIGSERIAL PRIMARY KEY,
 state_code TEXT NOT NULL UNIQUE,
 state_name TEXT NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE reference.districts (
 district_id BIGSERIAL PRIMARY KEY,
 district_code TEXT NOT NULL UNIQUE,
 district_name TEXT NOT NULL,
 state_id BIGINT NOT NULL
 REFERENCES reference.states(state_id),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE reference.schemes (
 scheme_id BIGSERIAL PRIMARY KEY,
 scheme_code TEXT UNIQUE,
 ministry_department TEXT NOT NULL,
 scheme_name TEXT NOT NULL,
 scheme_type TEXT,
 benefit_type TEXT,
 source_fy TEXT,
 dbt_fund_expenditure NUMERIC(18,2),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE reference.banks (
 bank_id BIGSERIAL PRIMARY KEY,
 bank_name TEXT NOT NULL,
 bank_code TEXT UNIQUE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


--Creating Operational tables to represent business workflow via synthetic records.Foreign keys ensure relationships between the tables.

CREATE TABLE ops.beneficiaries (
 beneficiary_id BIGSERIAL PRIMARY KEY,
 beneficiary_ref TEXT NOT NULL UNIQUE,
 state_id BIGINT REFERENCES reference.states(state_id),
 district_id BIGINT REFERENCES reference.districts(district_id),
 bank_id BIGINT REFERENCES reference.banks(bank_id),
 beneficiary_type TEXT NOT NULL
 CHECK (beneficiary_type IN ('INDIVIDUAL','HOUSEHOLD')),
 registration_date DATE NOT NULL,
 record_status TEXT NOT NULL DEFAULT 'ACTIVE'
 CHECK (record_status IN ('ACTIVE','INACTIVE')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE ops.applications (
 application_id BIGSERIAL PRIMARY KEY,
 application_ref TEXT NOT NULL UNIQUE,
 beneficiary_id BIGINT NOT NULL
 REFERENCES ops.beneficiaries(beneficiary_id),
 scheme_id BIGINT NOT NULL
 REFERENCES reference.schemes(scheme_id),
 application_date DATE NOT NULL,
 application_status TEXT NOT NULL
 CHECK (application_status IN
 ('SUBMITTED','VERIFIED','APPROVED','REJECTED','CANCELLED')),
 requested_amount NUMERIC(14,2) NOT NULL
 CHECK (requested_amount >= 0),
 verification_date DATE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 CHECK (verification_date IS NULL
 OR verification_date >= application_date)
);

CREATE TABLE ops.approvals (
 approval_id BIGSERIAL PRIMARY KEY,
 application_id BIGINT NOT NULL UNIQUE
 REFERENCES ops.applications(application_id),
 approval_date DATE NOT NULL,
 approved_amount NUMERIC(14,2) NOT NULL
 CHECK (approved_amount >= 0),
 approval_status TEXT NOT NULL
 CHECK (approval_status IN ('APPROVED','REJECTED','CANCELLED')),
 verification_reference TEXT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE ops.payment_instructions (
 payment_instruction_id BIGSERIAL PRIMARY KEY,
 instruction_ref TEXT NOT NULL UNIQUE,
 approval_id BIGINT NOT NULL
 REFERENCES ops.approvals(approval_id),
 instruction_date TIMESTAMPTZ NOT NULL,
 instruction_amount NUMERIC(14,2) NOT NULL
 CHECK (instruction_amount >= 0),
 instruction_status TEXT NOT NULL
 CHECK (instruction_status IN
 ('CREATED','SENT','PROCESSING','COMPLETED','CANCELLED')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE ops.payment_transactions (
 transaction_id BIGSERIAL PRIMARY KEY,
 payment_instruction_id BIGINT
 REFERENCES ops.payment_instructions(payment_instruction_id),
 beneficiary_id BIGINT
 REFERENCES ops.beneficiaries(beneficiary_id),
 transaction_reference TEXT NOT NULL UNIQUE,
 transaction_date TIMESTAMPTZ NOT NULL,
 settlement_date TIMESTAMPTZ,
 amount NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
 transaction_status TEXT NOT NULL
 CHECK (transaction_status IN
 ('SUCCESS','FAILED','PENDING','REVERSED')),
 failure_reason TEXT,
 bank_id BIGINT REFERENCES reference.banks(bank_id),
 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 CHECK (settlement_date IS NULL
 OR settlement_date >= transaction_date)
);


-- Creating Audit and Control tables
CREATE TABLE audit.load_batches (
 load_batch_id BIGSERIAL PRIMARY KEY,
 source_file_name TEXT NOT NULL,
 source_dataset TEXT NOT NULL,
 loaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 row_count INTEGER,
 load_status TEXT NOT NULL
 CHECK (load_status IN ('STARTED','SUCCESS','FAILED')),
 notes TEXT
);


CREATE TABLE audit.data_quality_issues (
 issue_id BIGSERIAL PRIMARY KEY,
 load_batch_id BIGINT REFERENCES audit.load_batches(load_batch_id),
 table_name TEXT NOT NULL,
 record_key TEXT,
 issue_type TEXT NOT NULL,
 issue_description TEXT NOT NULL,
detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 issue_status TEXT NOT NULL DEFAULT 'OPEN'
 CHECK (issue_status IN ('OPEN','REVIEWED','RESOLVED','FALSE_POSITIVE'))
);

CREATE TABLE audit.anomaly_flags (
 anomaly_id BIGSERIAL PRIMARY KEY,
 transaction_id BIGINT
 REFERENCES ops.payment_transactions(transaction_id),
 anomaly_type TEXT NOT NULL,
 anomaly_score NUMERIC(10,4),
 rule_name TEXT NOT NULL,
 evidence TEXT,
 detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 review_status TEXT NOT NULL DEFAULT 'PENDING'
 CHECK (review_status IN ('PENDING','REVIEWED','CLEARED','ESCALATED'))
);


--Adding Indexes to foreign keys and common filtering columns when query patterns justify them

CREATE INDEX idx_districts_state_id
ON reference.districts(state_id);
CREATE INDEX idx_beneficiaries_district_id
ON ops.beneficiaries(district_id);
CREATE INDEX idx_applications_beneficiary_id
ON ops.applications(beneficiary_id);
CREATE INDEX idx_applications_scheme_id
ON ops.applications(scheme_id);
CREATE INDEX idx_transactions_instruction_id
ON ops.payment_transactions(payment_instruction_id);
CREATE INDEX idx_transactions_status_date
ON ops.payment_transactions(transaction_status, transaction_date);
CREATE INDEX idx_transactions_beneficiary_id
ON ops.payment_transactions(beneficiary_id);




--Importing existing CSV files but first creating staging tables which efficiently preseve my public datasets table structure
CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE staging.dbt_state_raw (
    id BIGINT,
    fy TEXT,
    state_name TEXT,
    state_code TEXT,
    state_score NUMERIC,
    rank TEXT,
    total_dbt_transfer NUMERIC,
    no_of_dbt_transactions BIGINT,
    loaded_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE staging.dbt_state_raw ALTER COLUMN loaded_at SET DEFAULT CURRENT_TIMESTAMP;

CREATE TABLE staging.dbt_district_raw (
    id BIGINT,
    fy TEXT,
    state_name TEXT,
    state_code TEXT,
    district_name TEXT,
    district_code TEXT,
    total_dbt_transfer NUMERIC,
	  no_of_dbt_transactions BIGINT,
    loaded_at TIMESTAMPTZ DEFAULT NOW()
);



DROP TABLE IF EXISTS staging.dbt_scheme_raw;

CREATE TABLE staging.dbt_scheme_raw (
    sno TEXT,
    ministry_department TEXT,
    scheme_name TEXT,
    benefit_type TEXT,
    dbt_fund_expenditure NUMERIC,
    source_fy TEXT,
    loaded_at TIMESTAMPTZ DEFAULT NOW()
);


-- Row counts
SELECT COUNT(*) FROM staging.dbt_state_raw;
SELECT COUNT(*) FROM staging.dbt_district_raw;
SELECT COUNT(*) FROM staging.dbt_scheme_raw;



-- Financial years
SELECT fy, COUNT(*)
FROM staging.dbt_state_raw
GROUP BY fy
ORDER BY fy


-- Missing values
SELECT
    COUNT(*) FILTER (WHERE state_name IS NULL) AS missing_state,
    COUNT(*) FILTER (WHERE state_code IS NULL) AS missing_state_code,
    COUNT(*) FILTER (WHERE total_dbt_transfer IS NULL) AS missing_transfer,
    COUNT(*) FILTER (WHERE no_of_dbt_transactions IS NULL)
        AS missing_transactions
FROM staging.dbt_state_raw;


-- Duplicate natural key candidates
SELECT state_code, fy, COUNT(*)
FROM staging.dbt_state_raw
GROUP BY state_code, fy
HAVING COUNT(*) > 1;


-- Negative or suspicious values
SELECT *
FROM staging.dbt_state_raw
WHERE total_dbt_transfer < 0
   OR no_of_dbt_transactions < 0;


--Loading Reference Data from Staging

INSERT INTO reference.states (state_code, state_name)
SELECT DISTINCT
    TRIM(state_code),
    TRIM(state_name)
FROM staging.dbt_state_raw
WHERE NULLIF(TRIM(state_code), '') IS NOT NULL
  AND NULLIF(TRIM(state_name), '') IS NOT NULL
ON CONFLICT (state_code) DO UPDATE
SET state_name = EXCLUDED.state_name;
INSERT INTO reference.districts
    (district_code, district_name, state_id)
SELECT DISTINCT
    d.district_code,
    d.district_name,
    s.state_id
FROM staging.dbt_district_raw d
JOIN reference.states s
  ON s.state_code = d.state_code
WHERE d.district_code IS NOT NULL
  AND d.district_name IS NOT NULL
ON CONFLICT (district_code) DO UPDATE
SET district_name = EXCLUDED.district_name,
    state_id = EXCLUDED.state_id;



INSERT INTO reference.states (state_code, state_name)
SELECT DISTINCT
    TRIM(state_code),
    TRIM(state_name)
FROM staging.dbt_state_raw
WHERE NULLIF(TRIM(state_code), '') IS NOT NULL
  AND NULLIF(TRIM(state_name), '') IS NOT NULL
ON CONFLICT (state_code) DO UPDATE
SET state_name = EXCLUDED.state_name;
INSERT INTO reference.districts
    (district_code, district_name, state_id)
SELECT DISTINCT
    d.district_code,
    d.district_name,
    s.state_id
FROM staging.dbt_district_raw d
JOIN reference.states s
  ON s.state_code = d.state_code
WHERE d.district_code IS NOT NULL
  AND d.district_name IS NOT NULL
ON CONFLICT (district_code) DO UPDATE
SET district_name = EXCLUDED.district_name,
    state_id = EXCLUDED.state_id;

--Loading Synthetic Operational Data

-- Insert one synthetic beneficiary
INSERT INTO ops.beneficiaries (
    beneficiary_ref,
    state_id,
    district_id,
    bank_id,
    beneficiary_type,
    registration_date
)
VALUES (
    'BEN-SYN-000001',
    1,
    1,
    1,
Page 7
DBT PostgreSQL Project Guide
    'HOUSEHOLD',
    DATE '2024-04-01'
);


-- Approved amount versus instruction amount
SELECT
    a.approval_id,
    a.approved_amount,
    pi.payment_instruction_id,
    pi.instruction_amount,
    pi.instruction_amount - a.approved_amount AS difference
FROM ops.approvals a
JOIN ops.payment_instructions pi
  ON pi.approval_id = a.approval_id
WHERE pi.instruction_amount <> a.approved_amount;


-- Applications without approvals
SELECT a.application_id, a.application_ref
FROM ops.applications a
LEFT JOIN ops.approvals ap
  ON ap.application_id = a.application_id
WHERE a.application_status = 'APPROVED'
  AND ap.approval_id IS NULL;
  
  -- Payment instructions without transactions
SELECT pi.payment_instruction_id, pi.instruction_ref
FROM ops.payment_instructions pi
LEFT JOIN ops.payment_transactions pt
  ON pt.payment_instruction_id = pi.payment_instruction_id
WHERE pi.instruction_status = 'COMPLETED'
  AND pt.transaction_id IS NULL;


-- Potential repeated successful payments
SELECT
    payment_instruction_id,
    beneficiary_id,
    amount,
    COUNT(*) AS successful_count,
    MIN(transaction_date) AS first_transaction,
    MAX(transaction_date) AS last_transaction
FROM ops.payment_transactions
WHERE transaction_status = 'SUCCESS'
GROUP BY payment_instruction_id, beneficiary_id, amount
HAVING COUNT(*) > 1;

-- Failed payment followed by a successful payment

WITH failed AS (
    SELECT payment_instruction_id, MIN(transaction_date) AS failed_at
    FROM ops.payment_transactions
    WHERE transaction_status = 'FAILED'
    GROUP BY payment_instruction_id
),
successful AS (
    SELECT payment_instruction_id, MIN(transaction_date) AS success_at
    FROM ops.payment_transactions
    WHERE transaction_status = 'SUCCESS'
    GROUP BY payment_instruction_id
)
SELECT
    f.payment_instruction_id,
    f.failed_at,
    s.success_at
FROM failed f
JOIN successful s
  ON s.payment_instruction_id = f.payment_instruction_id
WHERE s.success_at > f.failed_at;


--Delayed Payment Detection
SELECT
    pi.payment_instruction_id,
    pi.instruction_ref,
    pi.instruction_date,
    MIN(pt.transaction_date) AS first_transaction_date,
    MIN(pt.transaction_date) - pi.instruction_date
        AS processing_duration
FROM ops.payment_instructions pi
JOIN ops.payment_transactions pt
  ON pt.payment_instruction_id = pi.payment_instruction_id
WHERE pt.transaction_status = 'SUCCESS'
GROUP BY
    pi.payment_instruction_id,
    pi.instruction_ref,
    pi.instruction_date
HAVING MIN(pt.transaction_date)
       > pi.instruction_date + INTERVAL '7 days';



WITH ordered_transactions AS (
    SELECT
        transaction_id,
        payment_instruction_id,
        transaction_date,
        transaction_status,
        LAG(transaction_date) OVER (
            PARTITION BY payment_instruction_id
            ORDER BY transaction_date
        ) AS previous_transaction_date,
        ROW_NUMBER() OVER (
            PARTITION BY payment_instruction_id
            ORDER BY transaction_date
        ) AS attempt_number
    FROM ops.payment_transactions
)
SELECT *
FROM ordered_transactions
WHERE attempt_number > 1
ORDER BY payment_instruction_id, transaction_date;
19. Statistical Screening
WITH stats AS (
Page 9
DBT PostgreSQL Project Guide
    SELECT
        AVG(amount) AS mean_amount,
        STDDEV_SAMP(amount) AS sd_amount
    FROM ops.payment_transactions
    WHERE transaction_status = 'SUCCESS'
)
SELECT
    pt.transaction_id,
    pt.amount,
    s.mean_amount,
    s.sd_amount,
    CASE
        WHEN s.sd_amount IS NULL OR s.sd_amount = 0 THEN NULL
        ELSE (pt.amount - s.mean_amount) / s.sd_amount
    END AS z_score
FROM ops.payment_transactions pt
CROSS JOIN stats s
WHERE pt.transaction_status = 'SUCCESS';


---Replace view
CREATE OR REPLACE VIEW analytics.v_payment_monitoring AS
SELECT
    pt.transaction_id,
    pt.transaction_reference,
    pt.transaction_date,
    pt.amount,
    pt.transaction_status,
    pi.instruction_ref,
    pi.instruction_date,
    a.approval_date,
    a.approved_amount,
    app.application_ref,
    app.scheme_id,
    b.beneficiary_ref,
    s.state_name,
    d.district_name
FROM ops.payment_transactions pt
LEFT JOIN ops.payment_instructions pi
  ON pi.payment_instruction_id = pt.payment_instruction_id
LEFT JOIN ops.approvals a
  ON a.approval_id = pi.approval_id
LEFT JOIN ops.applications app
  ON app.application_id = a.application_id
LEFT JOIN ops.beneficiaries b
  ON b.beneficiary_id = pt.beneficiary_id
LEFT JOIN reference.states s
  ON s.state_id = b.state_id
LEFT JOIN reference.districts d
  ON d.district_id = b.district_id;


-- Orphan-like records where a transaction has no instruction
SELECT pt.*
FROM ops.payment_transactions pt
LEFT JOIN ops.payment_instructions pi
  ON pi.payment_instruction_id = pt.payment_instruction_id
WHERE pt.payment_instruction_id IS NOT NULL
  AND pi.payment_instruction_id IS NULL;
  
  
  -- Success records with a failure reason
SELECT *
FROM ops.payment_transactions
WHERE transaction_status = 'SUCCESS'
  AND NULLIF(TRIM(failure_reason), '') IS NOT NULL;
Page 10
DBT PostgreSQL Project Guide


-- Failed records without a failure reason
SELECT *
FROM ops.payment_transactions
WHERE transaction_status = 'FAILED'
  AND NULLIF(TRIM(failure_reason), '') IS NULL;
  
  -- Payment before instruction
SELECT pt.*, pi.instruction_date
FROM ops.payment_transactions pt
JOIN ops.payment_instructions pi
  ON pi.payment_instruction_id = pt.payment_instruction_id
WHERE pt.transaction_date < pi.instruction_date;


-- Run in a terminal, not inside a SQL editor:
pg_dump -U postgres -d dbt_monitoring -F c
  -f dbt_monitoring_backup.dump
createdb -U postgres dbt_monitoring_restore
pg_restore -U postgres -d dbt_monitoring_restore
  dbt_monitoring_backup.dump
Routine maintenance commands:
ANALYZE ops.payment_transactions;
VACUUM (ANALYZE) ops.payment_transactions;


-- Inspect table sizes
SELECT
    schemaname,
    relname,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;

-- List schemas
SELECT schema_name
FROM information_schema.schemata
ORDER BY schema_name;

-- List tables
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
ORDER BY table_schema, table_name;

-- Inspect columns
SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema IN ('reference','ops','audit','analytics')
ORDER BY table_schema, table_name, ordinal_position;-- Check active connections
SELECT pid, usename, datname, state, query
FROM pg_stat_activity
WHERE datname = 'dbt_monitoring';


