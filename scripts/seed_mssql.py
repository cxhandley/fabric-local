#!/usr/bin/env python3
"""
Seed MSSQL with sample tables.  Run once after docker compose up:
    python scripts/seed_mssql.py
"""

import os, time, pymssql

CONN = dict(
    server=os.getenv("MSSQL_HOST", "mssql"),
    port=os.getenv("MSSQL_PORT", "1433"),
    user=os.getenv("MSSQL_USER", "sa"),
    password=os.environ["MSSQL_PASSWORD"],  # must be set — no hardcoded fallback
)


def wait_for_sql():
    for i in range(30):
        try:
            pymssql.connect(**CONN, database="master").close()
            print("✅ MSSQL is ready")
            return
        except Exception:
            print(f"⏳ Waiting for MSSQL... ({i+1})")
            time.sleep(2)
    raise RuntimeError("MSSQL did not become ready")


def run():
    wait_for_sql()
    db = os.getenv("MSSQL_DB", "fabric_demo")
    conn = pymssql.connect(**CONN, database="master", autocommit=True)
    conn.cursor().execute(f"IF DB_ID('{db}') IS NULL CREATE DATABASE [{db}]")
    conn.close()

    conn = pymssql.connect(**CONN, database=db, autocommit=True)
    cur = conn.cursor()

    cur.execute("""
        IF OBJECT_ID('dbo.customers','U') IS NULL
        CREATE TABLE dbo.customers (
            customer_id INT PRIMARY KEY, name NVARCHAR(120),
            region NVARCHAR(50), signup_date DATE)
    """)
    cur.execute("DELETE FROM dbo.customers")
    cur.executemany("INSERT INTO dbo.customers VALUES (%d,%s,%s,%s)", [
        (1,"Contoso Ltd","West","2023-01-15"),
        (2,"Northwind Traders","East","2023-03-22"),
        (3,"Adventure Works","West","2023-06-10"),
        (4,"Fabrikam Inc","South","2023-07-01"),
        (5,"Tailspin Toys","East","2023-09-18"),
    ])

    cur.execute("""
        IF OBJECT_ID('dbo.orders','U') IS NULL
        CREATE TABLE dbo.orders (
            order_id INT PRIMARY KEY, customer_id INT, order_date DATE,
            product NVARCHAR(100), quantity INT, unit_price DECIMAL(10,2))
    """)
    cur.execute("DELETE FROM dbo.orders")
    cur.executemany("INSERT INTO dbo.orders VALUES (%d,%d,%s,%s,%d,%s)", [
        (101,1,"2024-01-05","Widget A",10,29.99),
        (102,1,"2024-01-20","Widget B",5,49.99),
        (103,2,"2024-02-11","Widget A",20,29.99),
        (104,3,"2024-02-15","Gadget X",2,199.99),
        (105,2,"2024-03-01","Widget C",15,39.99),
        (106,4,"2024-03-10","Gadget X",1,199.99),
        (107,5,"2024-03-22","Widget A",30,29.99),
        (108,3,"2024-04-05","Widget B",8,49.99),
        (109,1,"2024-04-18","Gadget Y",3,149.99),
        (110,4,"2024-05-02","Widget C",12,39.99),
    ])
    conn.close()
    print("✅ Seeded fabric_demo: customers (5 rows), orders (10 rows)")


if __name__ == "__main__":
    run()
