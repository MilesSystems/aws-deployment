locals {
  IsAurora = var.use_serverless == "true"
  IsNotAurora = var.use_serverless == "false"
  HasEngineVersion = !var.database_engine_version == ""
  EnablePerformanceInsightsCondition = var.enable_performance_insights == "true"
}

