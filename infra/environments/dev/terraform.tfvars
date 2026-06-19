subscription_id        = "cf83455a-73e2-41b7-b28b-fbbf1467713d"
product                = "demo"
environment            = "dev"
location               = "westeurope"
short_region           = "weu"
function_public_access = true
target_backend_url     = "https://your-cp-backend.internal"
function_maximum_instance_count = 10
log_analytics_retention_days    = 30

schedules = [
  {
    name      = "expired-programs"
    job_name  = "UpcomingExpiredPrograms"
    frequency = "Day"
    interval  = 1
  },
  {
    name      = "weekly-cleanup"
    job_name  = "WeeklyExpiredCleanup"
    frequency = "Week"
    interval  = 1
  },
  {
    name      = "hourly-reconcile"
    job_name  = "HourlyReconciliation"
    frequency = "Hour"
    interval  = 12
  }
]
