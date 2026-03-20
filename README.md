# Fabric-Local: PySpark + MSSQL Data Lakehouse

A local "Microsoft Fabric-like" experience running in Docker, driven from
**VS Code** via Dev Containers. Includes PySpark kernels, Spark SQL kernels,
a Parquet data lake, MSSQL Server 2022, and a **doit** pipeline that
orchestrates Jupyter notebooks.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  VS Code (Windows) ── Dev Container ──► spark-dev   │
│    ├── PySpark 3.5 Jupyter kernel                   │
│    ├── Spark SQL kernel (spylon-kernel / %%sql)      │
│    ├── doit pipeline runner                          │
│    └── /workspace  (bind-mounted project)            │
├──────────────────────────────────────────────────────┤
│  mssql container  (SQL Server 2022)                  │
│    └── localhost:1433                                │
├──────────────────────────────────────────────────────┤
│  Parquet Data Lake  (./data/lake)                    │
│    raw/ → bronze/ → silver/ → gold/                  │
└──────────────────────────────────────────────────────┘
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

## Kernels

| Kernel | Language | Use for |
|--------|----------|---------|
| **PySpark 3.5** | Python | DataFrame API, MLlib, UDFs, `spark.sql()` |
| **spylon-kernel** | Scala / SQL | Pure Spark SQL via `%%sql` magic |

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

Commands: `doit` (run all), `doit list` (show tasks), `doit forget` (reset).

## MSSQL Connection

| Property | Value |
|----------|-------|
| Host | `mssql` (from container) / `localhost` (from Windows) |
| Port | `1433` |
| User | `sa` |
| Password | value of `MSSQL_SA_PASSWORD` in `.env` |
| Database | value of `MSSQL_DB` in `.env` |

## Troubleshooting

**MSSQL not ready?**
The healthcheck takes up to 30s. Run `docker compose logs mssql` to check.
The seed script retries automatically.

**Kernels not showing?**
Run `jupyter kernelspec list` in the terminal to verify both `pyspark` and
`spylon-kernel` are installed. Reopen the notebook if needed.

**Want to reset everything?**
```powershell
docker compose down -v          # removes containers + MSSQL data volume
docker compose up -d --build    # fresh start
```
