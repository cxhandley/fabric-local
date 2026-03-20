# Fabric-Local: PySpark + MSSQL Data Lakehouse

A local "Microsoft Fabric-like" experience running in Docker, driven from
**Positron** via Remote SSH. Includes PySpark kernels, Spark SQL kernels,
a Parquet data lake, MSSQL Server 2022, and a **doit** pipeline that
orchestrates Jupyter notebooks.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Positron (Windows)  ──SSH──►  spark-dev container   │
│    ├── PySpark Jupyter kernel                        │
│    ├── Spark SQL kernel (spylon-kernel)               │
│    ├── doit pipeline runner                           │
│    └── /workspace  (bind-mounted project)             │
├──────────────────────────────────────────────────────┤
│  mssql container  (SQL Server 2022)                   │
│    └── localhost:1433                                 │
├──────────────────────────────────────────────────────┤
│  Parquet Data Lake  (./data/lake)                     │
│    raw/ → bronze/ → silver/ → gold/                   │
└──────────────────────────────────────────────────────┘
```

## Prerequisites

- **Docker Desktop for Windows** (WSL 2 backend recommended)
- **Positron** (any version — https://github.com/posit-dev/positron/releases)

## Quick Start

### Step 1 — Build and start containers

```powershell
cd fabric-local
docker compose up -d --build
```

First run takes ~5 min (downloads JDK, Spark, MSSQL). Wait until both
containers show as healthy:

```powershell
docker compose ps
```

### Step 2 — Connect Positron via Remote SSH

1. Open Positron
2. Install the **Open Remote SSH** extension:
   - Go to Extensions (`Ctrl+Shift+X`)
   - Search: `jeanp413.open-remote-ssh`
   - Install it
3. Connect to the container:
   - `Ctrl+Shift+P` → **"Remote-SSH: Connect to Host"**
   - Enter: `spark@localhost -p 2222`
   - Password: `positron`
4. Once connected, click **"Open Folder"** → type `/workspace` → Open

You're now inside the container. The terminal, file explorer, notebooks,
and kernels all run inside Docker — but Positron's UI is native on Windows.

### Step 3 — Seed data and run the pipeline

Open the terminal in Positron (`Ctrl+\``) and run:

```bash
python scripts/seed_mssql.py    # creates fabric_demo DB + sample data
doit                             # runs all 3 notebooks in order
```

## Kernels

| Kernel | Language | Use for |
|--------|----------|---------|
| **PySpark 3.5** | Python | DataFrame API, MLlib, UDFs |
| **spylon-kernel** | Scala / SQL | Pure Spark SQL via `%%sql` magic |

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
| Password | `FabricLocal#2024` |
| Database | `fabric_demo` |

## Troubleshooting

**SSH connection refused?**
Make sure both containers are running: `docker compose ps`. The spark-dev
container must show as "running" before SSH will accept connections.

**MSSQL not ready?**
The healthcheck takes up to 30s. Run `docker compose logs mssql` to check.
The seed script retries automatically.

**Positron doesn't show kernels?**
After connecting via SSH, open a `.ipynb` file. Click the kernel picker
(top right of notebook) and select "PySpark 3.5" or "spylon-kernel".

**Want to reset everything?**
```powershell
docker compose down -v          # removes containers + MSSQL data volume
docker compose up -d --build    # fresh start
```
