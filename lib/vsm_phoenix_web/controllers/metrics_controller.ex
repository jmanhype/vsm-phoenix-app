defmodule VsmPhoenixWeb.MetricsController do
  @moduledoc """
  Metrics controller for Prometheus monitoring integration.
  """
  
  use VsmPhoenixWeb, :controller
  
  @doc """
  Prometheus metrics endpoint.
  Returns metrics in Prometheus format for scraping.
  """
  def metrics(conn, _params) do
    metrics = collect_prometheus_metrics()
    
    conn
    |> put_resp_content_type("text/plain; version=0.0.4; charset=utf-8")
    |> text(metrics)
  end
  
  @doc """
  JSON metrics endpoint for custom monitoring solutions.
  """
  def json_metrics(conn, _params) do
    metrics = collect_json_metrics()
    
    conn
    |> json(metrics)
  end
  
  # Private helper functions
  
  defp collect_prometheus_metrics do
    # Collect telemetry metrics and format for Prometheus
    telemetry_metrics = collect_telemetry_metrics()
    vm_metrics = collect_vm_metrics()
    vsm_metrics = collect_vsm_metrics()
    
    [telemetry_metrics, vm_metrics, vsm_metrics]
    |> Enum.join("\n")
  end
  
  defp collect_json_metrics do
    %{
      timestamp: DateTime.utc_now(),
      telemetry: collect_telemetry_metrics_json(),
      vm: collect_vm_metrics_json(),
      vsm: collect_vsm_metrics_json()
    }
  end
  
  defp collect_telemetry_metrics do
    # Phoenix request metrics
    """
    # HELP phoenix_requests_total Total number of Phoenix requests
    # TYPE phoenix_requests_total counter
    phoenix_requests_total{method="GET",status="200"} #{get_request_count("GET", 200)}
    phoenix_requests_total{method="POST",status="200"} #{get_request_count("POST", 200)}
    phoenix_requests_total{method="POST",status="401"} #{get_request_count("POST", 401)}
    
    # HELP phoenix_request_duration_seconds Phoenix request duration
    # TYPE phoenix_request_duration_seconds histogram
    phoenix_request_duration_seconds_bucket{le="0.1"} #{get_duration_bucket(0.1)}
    phoenix_request_duration_seconds_bucket{le="0.5"} #{get_duration_bucket(0.5)}
    phoenix_request_duration_seconds_bucket{le="1.0"} #{get_duration_bucket(1.0)}
    phoenix_request_duration_seconds_bucket{le="+Inf"} #{get_duration_bucket(:inf)}
    
    # HELP vsm_system_health VSM system health status
    # TYPE vsm_system_health gauge
    vsm_system_health{system="system1"} #{get_system_health(1)}
    vsm_system_health{system="system2"} #{get_system_health(2)}
    vsm_system_health{system="system3"} #{get_system_health(3)}
    vsm_system_health{system="system4"} #{get_system_health(4)}
    vsm_system_health{system="system5"} #{get_system_health(5)}
    """
  end
  
  defp collect_vm_metrics do
    memory = :erlang.memory()
    
    """
    # HELP erlang_vm_memory_bytes Memory usage by type
    # TYPE erlang_vm_memory_bytes gauge
    erlang_vm_memory_bytes{type="total"} #{memory[:total]}
    erlang_vm_memory_bytes{type="processes"} #{memory[:processes]}
    erlang_vm_memory_bytes{type="system"} #{memory[:system]}
    erlang_vm_memory_bytes{type="atom"} #{memory[:atom]}
    erlang_vm_memory_bytes{type="binary"} #{memory[:binary]}
    erlang_vm_memory_bytes{type="ets"} #{memory[:ets]}
    
    # HELP erlang_vm_process_count Number of Erlang processes
    # TYPE erlang_vm_process_count gauge
    erlang_vm_process_count #{:erlang.system_info(:process_count)}
    
    # HELP erlang_vm_scheduler_utilization Scheduler utilization
    # TYPE erlang_vm_scheduler_utilization gauge
    erlang_vm_scheduler_utilization #{get_scheduler_utilization()}
    """
  end
  
  defp collect_vsm_metrics do
    """
    # HELP vsm_variety_level Current variety level across VSM systems
    # TYPE vsm_variety_level gauge
    vsm_variety_level{system="system1"} #{get_variety_level(1)}
    vsm_variety_level{system="system2"} #{get_variety_level(2)}
    vsm_variety_level{system="system3"} #{get_variety_level(3)}
    vsm_variety_level{system="system4"} #{get_variety_level(4)}
    vsm_variety_level{system="system5"} #{get_variety_level(5)}
    
    # HELP vsm_viability_score Current viability score
    # TYPE vsm_viability_score gauge
    vsm_viability_score #{get_viability_score()}
    
    # HELP vsm_active_agents Number of active agents per system
    # TYPE vsm_active_agents gauge
    vsm_active_agents{system="system1"} #{get_active_agents(1)}
    
    # HELP vsm_processing_time_seconds Time spent processing VSM operations
    # TYPE vsm_processing_time_seconds histogram
    vsm_processing_time_seconds_bucket{system="system1",le="0.01"} #{get_processing_time_bucket(1, 0.01)}
    vsm_processing_time_seconds_bucket{system="system1",le="0.1"} #{get_processing_time_bucket(1, 0.1)}
    vsm_processing_time_seconds_bucket{system="system1",le="1.0"} #{get_processing_time_bucket(1, 1.0)}
    """
  end
  
  defp collect_telemetry_metrics_json do
    %{
      requests: %{
        total: get_total_requests(),
        by_method: get_requests_by_method(),
        by_status: get_requests_by_status()
      },
      response_times: %{
        avg: get_avg_response_time(),
        p95: get_percentile_response_time(95),
        p99: get_percentile_response_time(99)
      }
    }
  end
  
  defp collect_vm_metrics_json do
    memory = :erlang.memory()
    
    %{
      memory: memory,
      processes: %{
        count: :erlang.system_info(:process_count),
        limit: :erlang.system_info(:process_limit)
      },
      schedulers: %{
        online: :erlang.system_info(:schedulers_online),
        utilization: get_scheduler_utilization()
      }
    }
  end
  
  defp collect_vsm_metrics_json do
    %{
      systems: %{
        system1: %{health: get_system_health(1), variety: get_variety_level(1)},
        system2: %{health: get_system_health(2), variety: get_variety_level(2)},
        system3: %{health: get_system_health(3), variety: get_variety_level(3)},
        system4: %{health: get_system_health(4), variety: get_variety_level(4)},
        system5: %{health: get_system_health(5), variety: get_variety_level(5)}
      },
      viability_score: get_viability_score(),
      active_agents: get_total_active_agents()
    }
  end
  
  # Placeholder functions - these would connect to actual telemetry data
  defp get_request_count(_method, _status), do: 0
  defp get_duration_bucket(_threshold), do: 0
  defp get_system_health(_system), do: 1.0
  defp get_variety_level(_system), do: 0.5
  defp get_viability_score(), do: 0.8
  defp get_active_agents(_system), do: 5
  defp get_processing_time_bucket(_system, _threshold), do: 0
  defp get_scheduler_utilization(), do: 0.75
  defp get_total_requests(), do: 1000
  defp get_requests_by_method(), do: %{"GET" => 800, "POST" => 200}
  defp get_requests_by_status(), do: %{200 => 950, 404 => 30, 500 => 20}
  defp get_avg_response_time(), do: 0.05
  defp get_percentile_response_time(_percentile), do: 0.1
  defp get_total_active_agents(), do: 25
end