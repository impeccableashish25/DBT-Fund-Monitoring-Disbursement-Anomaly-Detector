import pandas as pd
import psycopg2
from psycopg2.extras import execute_values

# ----------------------------------------
# 1. PostgreSQL connection
# ----------------------------------------

conn = psycopg2.connect(
    host="localhost",
    port=5432,
    database="dbt_monitoring",
    user="postgres",
    password="Aashish_025"
)

cursor = conn.cursor()

# ----------------------------------------
# 2. Excel files and financial years
# ----------------------------------------

files = [
    ("data/scheme/scheme_dbt_transfer_2019_20.xlsx", "2019-20"),
    ("data/scheme/scheme_dbt_transfer_2020_21.xlsx", "2020-21")
]

# ----------------------------------------
# 3. Read and prepare each Excel file
# ----------------------------------------

all_data = []

for file_path, financial_year in files:

    print(f"Reading: {file_path}")

    df = pd.read_excel(file_path)

    # Standardize column names
    df.columns = (
        df.columns
        .str.strip()
        .str.lower()
        .str.replace("/", "_", regex=False)
        .str.replace(" ", "_", regex=False)
        .str.replace("-", "_", regex=False)
    )

    print("Columns found:")
    print(df.columns.tolist())

    # Dynamically inject the financial year from the tuple loop
    df["source_fy"] = financial_year

    # Keep only the required columns
    required_columns = [
        "sno",
        "ministry_department",
        "scheme_name",
        "benefit_type",
        "dbt_fund_expenditure",
        "source_fy"
    ]

    missing_columns = [
        col for col in required_columns
        if col not in df.columns
    ]

    if missing_columns:
        raise ValueError(
            f"Missing columns in {file_path}: {missing_columns}"
        )

    df = df[required_columns]

    # Convert blank strings to missing values
    df = df.replace(r"^\s*$", pd.NA, regex=True)

    # Convert amount to numeric
    df["dbt_fund_expenditure"] = pd.to_numeric(
        df["dbt_fund_expenditure"],
        errors="coerce"
    )

    # Convert NaN / NA values to Python None
    df = df.astype(object).where(pd.notna(df), None)

    all_data.append(df)

# ----------------------------------------
# 4. Combine both financial years
# ----------------------------------------

final_df = pd.concat(
    all_data,
    ignore_index=True
)

print("\nTotal rows to load:", len(final_df))

print("\nPreview:")
print(final_df.head())

# ----------------------------------------
# 5. Insert into PostgreSQL
# ----------------------------------------

records = []

# Fixed variable name from combined_df to final_df
for _, row in final_df.iterrows():
    records.append((
        row.get("sno"),
        row.get("ministry_department"),
        row.get("scheme_name"),
        row.get("benefit_type"),
        row.get("dbt_fund_expenditure"),
        row.get("source_fy")
    ))

try:
    with conn.cursor() as cur:

        execute_values(
            cur,
            """
            INSERT INTO staging.dbt_scheme_raw
            (
                sno,
                ministry_department,
                scheme_name,
                benefit_type,
                dbt_fund_expenditure,
                source_fy
            )
            VALUES %s
            """,
            records
        )

    conn.commit()

    print(f"SUCCESS: {len(records)} rows inserted into PostgreSQL.")

except Exception as e:
    conn.rollback()
    print("ERROR while inserting data:", e)

finally:
    conn.close()