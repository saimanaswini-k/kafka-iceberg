package com.example

import org.apache.spark.sql.SparkSession

/**
 * A utility application for querying Apache Iceberg tables using Apache Spark.
 * Demonstrates catalog-based SQL queries against Iceberg tables.
 */
object IcebergSparkQueries {
  def main(args: Array[String]): Unit = {
    val spark = SparkSession.builder()
      .appName("Iceberg Queries")
      .getOrCreate()
      
    // Basic query to select all data (limit to avoid large output)
    println("Basic SELECT query:")
    spark.sql("SELECT * FROM spark_catalog.default.json_data LIMIT 10").show()
    
    // Count records
    println("Count query:")
    spark.sql("SELECT COUNT(*) FROM spark_catalog.default.json_data").show()
    
    // Aggregation query
    println("Aggregation query:")
    spark.sql("""
      SELECT passenger_count, COUNT(*) as trip_count 
      FROM spark_catalog.default.json_data 
      GROUP BY passenger_count 
      ORDER BY trip_count DESC
    """).show()
    
    // Filter query
    println("Filter query:")
    spark.sql("""
      SELECT * FROM spark_catalog.default.json_data 
      WHERE trip_distance > '5.0' 
      LIMIT 10
    """).show()
    
    // Time travel query (to a specific timestamp)
    println("Time travel query:")
    try {
      spark.sql("""
        SELECT * FROM spark_catalog.default.json_data TIMESTAMP AS OF '2023-01-01 00:00:00' 
        LIMIT 10
      """).show()
    } catch {
      case e: Exception =>
        println(s"Time travel failed: ${e.getMessage}")
        println("Displaying current data instead:")
        spark.sql("SELECT * FROM spark_catalog.default.json_data LIMIT 10").show()
    }
    
    // View table history
    println("Table history:")
    spark.sql("SELECT * FROM spark_catalog.default.json_data.history").show()
    
    // View table snapshots
    println("Table snapshots:")
    spark.sql("SELECT * FROM spark_catalog.default.json_data.snapshots").show()
    
    spark.stop()
  }
} 