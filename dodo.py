"""
dodo.py — doit pipeline for Fabric-Local.

    doit               # run all tasks
    doit list          # list tasks
    doit forget        # reset → re-run everything
"""

import os, shutil

os.makedirs("notebooks/executed", exist_ok=True)


def _run_nb(name):
    src = f"notebooks/{name}"
    dst = f"notebooks/executed/{name}"
    return (
        f"papermill {src} {dst} "
        f"--cwd /workspace "
        f"--kernel pyspark"
    )


def task_ingest():
    """01 — Ingest MSSQL → Bronze Parquet."""
    return {
        "actions": [_run_nb("01_ingest.ipynb")],
        "file_dep": ["notebooks/01_ingest.ipynb"],
        "targets": ["data/lake/bronze/customers/_SUCCESS"],
        "clean": True, "verbosity": 2,
    }


def task_transform():
    """02 — Transform Bronze → Silver."""
    return {
        "actions": [_run_nb("02_transform.ipynb")],
        "file_dep": ["notebooks/02_transform.ipynb"],
        "task_dep": ["ingest"],
        "targets": ["data/lake/silver/order_details/_SUCCESS"],
        "clean": True, "verbosity": 2,
    }


def task_aggregate():
    """03 — Aggregate Silver → Gold + MSSQL write-back."""
    return {
        "actions": [_run_nb("03_aggregate.ipynb")],
        "file_dep": ["notebooks/03_aggregate.ipynb"],
        "task_dep": ["transform"],
        "targets": ["data/lake/gold/revenue_by_region/_SUCCESS"],
        "clean": True, "verbosity": 2,
    }


def task_seed():
    """Seed MSSQL with sample data."""
    return {"actions": ["python scripts/seed_mssql.py"], "verbosity": 2, "uptodate": [False]}


def task_clean_lake():
    """Remove all Parquet data from the lake."""
    def _clean():
        for zone in ["bronze", "silver", "gold"]:
            p = f"data/lake/{zone}"
            if os.path.exists(p):
                shutil.rmtree(p); os.makedirs(p)
                print(f"🧹 Cleaned {p}")
    return {"actions": [_clean], "verbosity": 2}
