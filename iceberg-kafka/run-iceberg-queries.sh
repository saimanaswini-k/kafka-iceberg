#!/bin/bash

# Script to run Iceberg Spark Queries against the Iceberg table

# Check if SPARK_HOME environment variable is set, otherwise use a default
if [ -z "$SPARK_HOME" ]; then
  echo "SPARK_HOME not set, please set it to your Spark installation directory"
  exit 1
fi

# Location of the jar file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JAR_PATH="$SCRIPT_DIR/target/scala-2.12/iceberg-kafka-assembly-0.1.0-SNAPSHOT.jar"

# Iceberg and Spark versions - must match the ones in build.sbt
ICEBERG_VERSION="1.5.0"
SPARK_VERSION="3.5.3"

echo "Checking for dependencies..."
if [ ! -f "$JAR_PATH" ]; then
  # Build the project with assembly to include all dependencies
  echo "Building project with assembly..."
  sbt clean assembly
else
  echo "Using existing JAR: $JAR_PATH"
fi

# Check if JAR was built successfully
if [ ! -f "$JAR_PATH" ]; then
  echo "Error: Failed to build the JAR file at $JAR_PATH"
  echo "Try running './run-kafka-iceberg-job.sh' first to resolve dependency issues"
  exit 1
fi

# Check if we have an Iceberg Queries class, if not, suggest creating one
if ! jar tf "$JAR_PATH" | grep -q "com/example/IcebergSparkQueries"; then
  echo "Warning: IcebergSparkQueries class not found in JAR."
  echo "You may need to create this class first. Here's a template:"
  echo "
  package com.example
  
  import org.apache.spark.sql.SparkSession
  
  object IcebergSparkQueries {
    def main(args: Array[String]): Unit = {
      val spark = SparkSession.builder()
        .appName(\"Iceberg Queries\")
        .getOrCreate()
        
      // Read from Iceberg table
      spark.sql(\"SELECT * FROM spark_catalog.default.json_data LIMIT 10\").show()
      
      // Run more queries as needed
      
      spark.stop()
    }
  }
  "
  read -p "Do you want to proceed anyway? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

echo "Running Iceberg queries..."
$SPARK_HOME/bin/spark-submit \
  --master local[*] \
  --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:$ICEBERG_VERSION \
  --conf "spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions" \
  --conf "spark.sql.catalog.spark_catalog=org.apache.iceberg.spark.SparkSessionCatalog" \
  --conf "spark.sql.catalog.spark_catalog.type=hive" \
  --conf "spark.sql.catalog.local=org.apache.iceberg.spark.SparkCatalog" \
  --conf "spark.sql.catalog.local.type=hadoop" \
  --conf "spark.sql.catalog.local.warehouse=$SCRIPT_DIR/data/warehouse" \
  --conf "spark.driver.extraJavaOptions=-Djava.io.tmpdir=/tmp" \
  --conf "spark.executor.extraJavaOptions=-Djava.io.tmpdir=/tmp" \
  --class com.example.IcebergSparkQueries \
  $JAR_PATH "$@"

# Check if job submission was successful
if [ $? -eq 0 ]; then
  echo "Job completed successfully."
  
  # List available Iceberg tables
  echo "Available Iceberg tables in warehouse:"
  $SPARK_HOME/bin/spark-submit \
    --master local[*] \
    --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:$ICEBERG_VERSION \
    --conf "spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions" \
    --conf "spark.sql.catalog.spark_catalog=org.apache.iceberg.spark.SparkSessionCatalog" \
    --conf "spark.sql.catalog.spark_catalog.type=hive" \
    --conf "spark.sql.catalog.local=org.apache.iceberg.spark.SparkCatalog" \
    --conf "spark.sql.catalog.local.type=hadoop" \
    --conf "spark.sql.catalog.local.warehouse=$SCRIPT_DIR/data/warehouse" \
    --class org.apache.spark.sql.SparkSession \
    -e "spark.sql(\"SHOW TABLES IN spark_catalog.default\").show()"
else
  echo "Error: Failed to submit the Spark job. Check the logs for details."
  exit 1
fi 