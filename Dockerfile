FROM eclipse-temurin:11-jdk-jammy

# ── System deps ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl wget git unzip python3 python3-pip python3-venv \
        build-essential libffi-dev libpq-dev sudo \
        openssh-client libicu70 \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 20 (required for Claude Code) ─────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# ── Claude Code ───────────────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code

# ── Spark 3.5.1 ──────────────────────────────────────────────────────
ENV SPARK_VERSION=3.5.1
ENV HADOOP_VERSION=3
ENV SPARK_HOME=/opt/spark
ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="${JAVA_HOME}/bin:${SPARK_HOME}/bin:${SPARK_HOME}/sbin:${PATH}"

RUN wget -qO /tmp/spark.tgz \
    "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" \
    && mkdir -p /opt/spark \
    && tar -xzf /tmp/spark.tgz --strip-components=1 -C /opt/spark \
    && rm /tmp/spark.tgz

# ── MSSQL JDBC driver ────────────────────────────────────────────────
RUN wget -qO /opt/spark/jars/mssql-jdbc-12.4.2.jre11.jar \
    "https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.4.2.jre11/mssql-jdbc-12.4.2.jre11.jar"

# ── Delta Lake JARs ──────────────────────────────────────────────────
RUN wget -qO /opt/spark/jars/delta-spark_2.12-3.1.0.jar \
    "https://repo1.maven.org/maven2/io/delta/delta-spark_2.12/3.1.0/delta-spark_2.12-3.1.0.jar" \
    && wget -qO /opt/spark/jars/delta-storage-3.1.0.jar \
    "https://repo1.maven.org/maven2/io/delta/delta-storage/3.1.0/delta-storage-3.1.0.jar"

# ── Python packages ──────────────────────────────────────────────────
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

# ── python → python3 symlink ─────────────────────────────────────────
RUN ln -sf /usr/bin/python3 /usr/bin/python

# ── Jupyter kernels ──────────────────────────────────────────────────
# PySpark kernel with env vars baked in
RUN mkdir -p /usr/local/share/jupyter/kernels/pyspark \
    && printf '{\n\
  "display_name": "PySpark 3.5",\n\
  "language": "python",\n\
  "argv": [\n\
    "/usr/bin/python3", "-m", "ipykernel_launcher", "-f", "{connection_file}"\n\
  ],\n\
  "env": {\n\
    "JAVA_HOME": "/opt/java/openjdk",\n\
    "SPARK_HOME": "/opt/spark",\n\
    "PYSPARK_PYTHON": "/usr/bin/python3",\n\
    "PYSPARK_DRIVER_PYTHON": "/usr/bin/python3",\n\
    "PATH": "/opt/java/openjdk/bin:/opt/spark/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"\n\
  }\n\
}\n' > /usr/local/share/jupyter/kernels/pyspark/kernel.json

# Spylon kernel (Spark SQL) with env vars patched in
RUN python3 -m spylon_kernel install --sys-prefix \
    && python3 -c "\
import json, glob, pathlib; \
dirs = glob.glob('/usr/local/**/kernels/spylon-kernel/kernel.json', recursive=True); \
[pathlib.Path(d).write_text(json.dumps({**json.loads(pathlib.Path(d).read_text()), \
  'env': {'JAVA_HOME':'/opt/java/openjdk','SPARK_HOME':'/opt/spark', \
  'PATH':'/opt/java/openjdk/bin:/opt/spark/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'}}, indent=2)) \
for d in dirs]"

# DuckDB kernel
RUN DUCKDB_KERNEL_DIR=$(pip3 show jupyter-duckdb | grep Location | cut -d' ' -f2)/duckdb_kernel \
    && echo "Installing DuckDB kernel from: $DUCKDB_KERNEL_DIR" \
    && ls -la "$DUCKDB_KERNEL_DIR/kernel.json" \
    && jupyter kernelspec install "$DUCKDB_KERNEL_DIR" --name duckdb --sys-prefix


# ── Spark defaults ────────────────────────────────────────────────────
COPY conf/spark-defaults.conf /opt/spark/conf/spark-defaults.conf

# ── Env vars ──────────────────────────────────────────────────────────
ENV PYSPARK_PYTHON=python3
ENV PYSPARK_DRIVER_PYTHON=python3

# ── Pre-commit + nbstripout setup ─────────────────────────────────────
RUN git config --system init.templateDir /usr/share/git-core/templates

WORKDIR /workspace

CMD ["sleep", "infinity"]
