# Fabric-Local: PySpark + MSSQL Data Lakehouse

A local "Microsoft Fabric-like" experience running in Docker, driven from
**VS Code** via Dev Containers. Includes PySpark kernels, Spark SQL kernels,
a DuckDB kernel, a Parquet data lake, MSSQL Server 2022, and a **doit** pipeline
that orchestrates Jupyter notebooks via Papermill.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  VS Code (Windows) ── Dev Container ──► spark-dev   │
│    ├── PySpark 3.5 Jupyter kernel                   │
│    ├── Spark SQL kernel (spylon-kernel / %%sql)      │
│    ├── DuckDB kernel                                 │
│    ├── doit pipeline runner                          │
│    └── /workspace  (bind-mounted project)            │
├──────────────────────────────────────────────────────┤
│  mssql container  (SQL Server 2022)                  │
│    └── localhost:1433                                │
├──────────────────────────────────────────────────────┤
│  Parquet Data Lake  (./data/lake)                    │
│    bronze/ → silver/ → gold/                         │
└──────────────────────────────────────────────────────┘
```

**Pipeline flow:**

```
MSSQL (fabric_demo DB)
    ↓  01_ingest.ipynb
data/lake/bronze/     (raw Parquet from MSSQL)
    ↓  02_transform.ipynb
data/lake/silver/     (cleaned, partitioned Parquet)
    ↓  03_aggregate.ipynb
data/lake/gold/       + write-back to MSSQL
```

## Prerequisites

- **Docker Desktop for Windows** (WSL 2 backend recommended)
- **VS Code** with the **Dev Containers** extension (`ms-vscode-remote.remote-containers`)

## Quick Start

### Step 1 — Create your .env file

```powershell
cd fabric-local
copy .env.template .env
```

Edit `.env` and set your passwords:

```env
MSSQL_SA_PASSWORD=YourStrongPassword123!
MSSQL_DB=fabric_demo
MSSQL_HOST=mssql
MSSQL_PORT=1433
MSSQL_USER=sa
```

### Step 2 — Open in Dev Container

1. Open the `fabric-local` folder in VS Code
2. VS Code detects `.devcontainer/devcontainer.json` and prompts:
   **"Reopen in Container"** — click it
3. First build takes ~5 min (downloads JDK, Spark, MSSQL image)
4. Once built, you're inside the container with full access to
   terminal, notebooks, kernels, and the MSSQL extension

### Step 3 — Seed data and run the pipeline

Open the terminal in VS Code (`` Ctrl+` ``) and run:

```bash
python scripts/seed_mssql.py    # creates fabric_demo DB + sample data
doit                             # runs all 3 notebooks in order
```

Notebooks are executed headlessly via **Papermill**; outputs are saved to `notebooks/executed/`.

## Kernels

| Kernel | Language | Use for |
|--------|----------|---------|
| **PySpark 3.5** | Python | DataFrame API, MLlib, UDFs, `spark.sql()` |
| **spylon-kernel** | Scala / SQL | Pure Spark SQL via `%%sql` magic |
| **DuckDB** | SQL | Local SQL analytics without Spark overhead |

Select a kernel from the notebook kernel picker (top right of any `.ipynb` file).

## Notebooks

| Notebook | Kernel | Purpose |
|----------|--------|---------|
| `01_ingest.ipynb` | PySpark | MSSQL → bronze Parquet |
| `02_transform.ipynb` | PySpark | bronze → silver (join + enrich) |
| `03_aggregate.ipynb` | PySpark | silver → gold + MSSQL write-back |
| `spark_sql_sandbox.ipynb` | spylon-kernel | Interactive Spark SQL via `%%sql` |
| `spark_sql_via_pyspark.ipynb` | PySpark | Spark SQL through `spark.sql()` |

## doit Pipeline

```
01_ingest.ipynb    → MSSQL tables  ──► bronze/ Parquet
02_transform.ipynb → bronze/       ──► silver/ Parquet (partitioned)
03_aggregate.ipynb → silver/       ──► gold/   Parquet + MSSQL write-back
```

Commands: `doit` (run all), `doit list` (show tasks), `doit forget` (reset state to force re-run).

## Key Files

| File | Purpose |
|------|---------|
| `dodo.py` | doit task definitions; pipeline DAG with Papermill execution and dependencies |
| `scripts/spark_session.py` | Shared SparkSession factory and JDBC helpers used by all notebooks |
| `scripts/seed_mssql.py` | Creates `fabric_demo` database with `customers` and `orders` tables |
| `conf/spark-defaults.conf` | Spark config (2GB memory, Delta Lake catalog, MSSQL JDBC driver path) |
| `Dockerfile` | Builds the container: Java 11, Spark 3.5.1, Python packages, JDBC jar, Delta Lake jars, Claude Code CLI |

## Ports

| Service | Port |
|---------|------|
| Jupyter | 8888 |
| Spark UI | 4040 |
| MSSQL | 1433 |

## MSSQL Connection

| Property | Value |
|----------|-------|
| Host | `mssql` (from container) / `localhost` (from Windows) |
| Port | `1433` |
| User | `sa` |
| Password | value of `MSSQL_SA_PASSWORD` in `.env` |
| Database | value of `MSSQL_DB` in `.env` |

## Delta Lake & JDBC

Delta Lake JARs (3.1.0) are pre-installed in the container. The MSSQL JDBC driver (12.4.2) is at `/opt/spark/jars/`. Both are referenced in `conf/spark-defaults.conf` and loaded automatically by the SparkSession in `scripts/spark_session.py`.

## Notebook Git Hygiene

**nbstripout** is configured via `.gitattributes` to automatically strip notebook outputs on `git add`. The pre-commit hook also enforces this. Never commit notebooks with outputs — they will be regenerated by `doit`.

Run all pre-commit hooks manually with:

```bash
pre-commit run --all-files
```

## Troubleshooting

**MSSQL not ready?**
The healthcheck takes up to 30s. Run `docker compose logs mssql` to check.
The seed script retries automatically.

**Kernels not showing?**
Run `jupyter kernelspec list` in the terminal to verify `pyspark`, `spylon-kernel`, and `duckdb-kernel` are installed. Reopen the notebook if needed.

**Want to reset everything?**
```powershell
docker compose down -v          # removes containers + MSSQL data volume
docker compose up -d --build    # fresh start
```
