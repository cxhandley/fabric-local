FROM eclipse-temurin:11-jdk-jammy

# ── System deps + SSH ─────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl wget git unzip python3 python3-pip python3-venv \
        build-essential libffi-dev libpq-dev \
        openssh-server sudo \
    && rm -rf /var/lib/apt/lists/*

# ── SSH setup (Positron Remote SSH) ───────────────────────────────────
RUN mkdir -p /var/run/sshd \
    && useradd -m -s /bin/bash spark \
    && echo 'spark:positron' | chpasswd \
    && usermod -aG sudo spark \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# ── Spark 3.5.1 ──────────────────────────────────────────────────────
ENV SPARK_VERSION=3.5.1
ENV HADOOP_VERSION=3
ENV SPARK_HOME=/opt/spark
ENV PATH="${SPARK_HOME}/bin:${SPARK_HOME}/sbin:${PATH}"

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

# ── Python packages (no --break-system-packages, old pip in jammy) ───
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

# ── Jupyter kernels ──────────────────────────────────────────────────
RUN python3 -m ipykernel install --name pyspark --display-name "PySpark 3.5"
RUN python3 -m spylon_kernel install

# ── Make kernels available to the spark user too ─────────────────────
RUN cp -r /usr/local/share/jupyter/kernels /home/spark/.local/share/jupyter/kernels 2>/dev/null || true \
    && mkdir -p /home/spark/.local/share/jupyter \
    && cp -r /root/.local/share/jupyter/kernels /home/spark/.local/share/jupyter/ 2>/dev/null || true \
    && chown -R spark:spark /home/spark/.local

# ── Spark defaults ────────────────────────────────────────────────────
COPY conf/spark-defaults.conf /opt/spark/conf/spark-defaults.conf

# ── Env vars baked in (also set via compose, belt+suspenders) ─────────
ENV PYSPARK_PYTHON=python3
ENV PYSPARK_DRIVER_PYTHON=python3

RUN sudo ln -s /usr/bin/python3 /usr/bin/python

RUN echo 'export JAVA_HOME=/opt/java/openjdk' >> /home/spark/.bashrc \
    && echo 'export SPARK_HOME=/opt/spark' >> /home/spark/.bashrc \
    && echo 'export PATH=$JAVA_HOME/bin:$SPARK_HOME/bin:$PATH' >> /home/spark/.bashrc

WORKDIR /workspace

# ── Start SSH + keep alive ────────────────────────────────────────────
CMD bash -c "/usr/sbin/sshd && echo '✅ SSH on port 22 — connect: ssh spark@localhost -p 2222' && sleep infinity"
