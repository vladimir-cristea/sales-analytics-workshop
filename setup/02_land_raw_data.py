# Databricks notebook source
# MAGIC %md
# MAGIC # Step 2 - Land the committed JSON into the UC volume
# MAGIC
# MAGIC Transparency copy of section 4 of `00_bootstrap` - copies the repo's `raw/` and
# MAGIC `clean/` JSON into the volume with **no manual upload**.
# MAGIC
# MAGIC ## Volume-copy robustness (known gotcha)
# MAGIC Writing repo files into a UC volume on serverless has historically been flaky. The
# MAGIC `copy_into_volume` helper tries three methods in order and reports which one worked:
# MAGIC 1. **FUSE write** - `open(volume_path, "wb")` (works on this workspace),
# MAGIC 2. **`dbutils.fs.cp`** with an explicit `file:` scheme,
# MAGIC 3. **SDK Files API** - `WorkspaceClient().files.upload(...)` (REST, FUSE-independent).

# COMMAND ----------

import os, io

CATALOG, SCHEMA, VOLUME = "workshop", "shared_data", "data"
VOLUME_ROOT = f"/Volumes/{CATALOG}/{SCHEMA}/{VOLUME}"

# Repo data dir - derived from this notebook's path (repo_root/data).
nb_path = (dbutils.notebook.entry_point.getDbutils().notebook()
           .getContext().notebookPath().get())
repo_root = os.path.dirname(os.path.dirname(nb_path))
DATA_DIR = next(c for c in (f"/Workspace{repo_root}/data", f"{repo_root}/data", f"{repo_root}/data/data")
                if os.path.isdir(c))
print("Repo data dir:", DATA_DIR)

# COMMAND ----------

def copy_into_volume(src_file, dst_file):
    os.makedirs(os.path.dirname(dst_file), exist_ok=True)
    errs = {}
    try:
        with open(src_file, "rb") as f:
            data = f.read()
        with open(dst_file, "wb") as f:
            f.write(data)
        if os.path.getsize(dst_file) == len(data):
            return "fuse_open_write"
    except Exception as e:
        errs["fuse"] = repr(e)[:200]
    try:
        dbutils.fs.cp(f"file:{src_file}", dst_file)
        return "dbutils_fs_cp"
    except Exception as e:
        errs["dbutils"] = repr(e)[:200]
    try:
        from databricks.sdk import WorkspaceClient
        with open(src_file, "rb") as f:
            data = f.read()
        WorkspaceClient().files.upload(dst_file, io.BytesIO(data), overwrite=True)
        return "sdk_files_api"
    except Exception as e:
        errs["sdk"] = repr(e)[:200]
    raise RuntimeError(f"All copy methods failed for {src_file}: {errs}")

for flavour in ("raw", "clean"):
    for entity in ("customers", "products", "orders"):
        src = f"{DATA_DIR}/{flavour}/{entity}/{entity}.json"
        dst = f"{VOLUME_ROOT}/{flavour}/{entity}/{entity}.json"
        method = copy_into_volume(src, dst)
        print(f"  {flavour}/{entity}: {method} -> {dst} ({os.path.getsize(dst):,} bytes)")
