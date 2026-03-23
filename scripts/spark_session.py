"""
Shared SparkSession factory for the Fabric-Local project.

    from scripts.spark_session import get_spark, JDBC_URL, JDBC_PROPS
"""

import os
from pyspark.sql import SparkSession


def get_spark(app_name: str = "FabricLocal") -> SparkSession:
    """Return a configured SparkSession (creates one if needed)."""
    return (
        SparkSession.builder
        .appName(app_name)
        .master("local[*]")
        .config("spark.sql.warehouse.dir", "/workspace/data/lake")
        .config("spark.sql.parquet.compression.codec", "snappy")
        .config("spark.sql.sources.default", "parquet")
        .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
        .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
        .config("spark.jars", "/opt/spark/jars/mssql-jdbc-12.4.2.jre11.jar")
        .getOrCreate()
    )


# ── MSSQL JDBC helpers (all values from environment, no defaults for secrets) ─
MSSQL_HOST = os.getenv("MSSQL_HOST", "mssql")
MSSQL_PORT = os.getenv("MSSQL_PORT", "1433")
MSSQL_USER = os.getenv("MSSQL_USER", "sa")
MSSQL_PASSWORD = os.environ["MSSQL_PASSWORD"]  # must be set — no hardcoded fallback
MSSQL_DB = os.getenv("MSSQL_DB", "fabric_demo")

JDBC_URL = (
    f"jdbc:sqlserver://{MSSQL_HOST}:{MSSQL_PORT};"
    f"databaseName={MSSQL_DB};encrypt=false;trustServerCertificate=true"
)

JDBC_PROPS = {
    "user": MSSQL_USER,
    "password": MSSQL_PASSWORD,
    "driver": "com.microsoft.sqlserver.jdbc.SQLServerDriver",
}

LAKE_ROOT = "/workspace/data/lake"
RAW = f"{LAKE_ROOT}/raw"
BRONZE = f"{LAKE_ROOT}/bronze"
SILVER = f"{LAKE_ROOT}/silver"
GOLD = f"{LAKE_ROOT}/gold"
