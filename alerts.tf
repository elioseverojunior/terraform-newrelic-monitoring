data "newrelic_application" "app" {
  name = var.newrelic_fully_qualified_app_name
}

resource "newrelic_alert_policy" "non_urgent" {
  name = "${var.newrelic_app_name} Non Urgent"
}

resource "newrelic_alert_policy" "urgent" {
  name = "${var.newrelic_app_name} Urgent"
}

# health check monitor

resource "newrelic_synthetics_monitor" "health_check" {
  name      = "${var.newrelic_app_name} Health check"
  type      = "SIMPLE"
  uri       = var.service_url
  frequency = 1
  status    = "ENABLED"
  locations = ["AWS_US_EAST_1", "AWS_US_WEST_1", "AWS_EU_WEST_1", "AWS_EU_WEST_3", "AWS_AP_NORTHEAST_1", "AWS_AP_SOUTHEAST_2"]
}

# urgent conditions

resource "newrelic_synthetics_alert_condition" "health_check" {
  policy_id = newrelic_alert_policy.urgent.id

  name        = "Health check"
  monitor_id  = newrelic_synthetics_monitor.health_check.id
  runbook_url = var.runbook_url
}

resource "newrelic_nrql_alert_condition" "error_rate_5xx" {
  policy_id = newrelic_alert_policy.urgent.id

  name        = "Too many sustained 5xx errors"
  runbook_url = var.runbook_url
  enabled     = true

  term {
    duration      = 5 # s
    operator      = "above"
    priority      = "critical"
    threshold     = "10" # percentage
    time_function = "all"
  }

  nrql {
    query = <<-EOF
        SELECT percentage(count(*), WHERE response.status LIKE '5%')
        FROM Transaction
        WHERE appName = '${var.newrelic_fully_qualified_app_name}'
        EOF

    since_value = "3" # s
  }

  value_function = "single_value"
}

resource "newrelic_nrql_alert_condition" "high_latency_urgent" {
  policy_id = newrelic_alert_policy.urgent.id

  name        = "High latency for 50% of requests"
  runbook_url = var.runbook_url
  enabled     = true

  term {
    duration      = 5 # s
    operator      = "above"
    priority      = "critical"
    threshold     = "1000" # ms
    time_function = "all"
  }

  nrql {
    query = <<-EOF
        SELECT percentile(duration * 1000, 50)
        FROM Transaction
        WHERE appName = '${var.newrelic_fully_qualified_app_name}'
        EOF

    since_value = "3" # s
  }

  value_function = "single_value"
}

# non-urgent conditions

resource "newrelic_nrql_alert_condition" "error_rate_4xx" {
  policy_id = newrelic_alert_policy.non_urgent.id

  name        = "Too many sustained 4xx errors"
  runbook_url = var.runbook_url
  enabled     = true

  term {
    duration      = 5 # s
    operator      = "above"
    priority      = "critical"
    threshold     = "30" # percentage
    time_function = "all"
  }

  nrql {
    query = <<-EOF
        SELECT percentage(count(*), WHERE response.status LIKE '4%')
        FROM Transaction
        WHERE appName = '${var.newrelic_fully_qualified_app_name}'
        EOF

    since_value = "3" # s
  }

  value_function = "single_value"
}

resource "newrelic_nrql_alert_condition" "high_latency_non_urgent" {
  policy_id = newrelic_alert_policy.non_urgent.id

  name        = "High latency for 1% of requests"
  runbook_url = var.runbook_url
  enabled     = true

  term {
    duration      = 5 # s
    operator      = "above"
    priority      = "critical"
    threshold     = "1000" # ms
    time_function = "all"
  }

  nrql {
    query = <<-EOF
        SELECT percentile(duration * 1000, 99)
        FROM Transaction
        WHERE appName = '${var.newrelic_fully_qualified_app_name}'
        EOF

    since_value = "3" # s
  }

  value_function = "single_value"
}
