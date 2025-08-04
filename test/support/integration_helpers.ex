defmodule VsmPhoenix.IntegrationHelpers do
  @moduledoc """
  Helper functions for integration testing.
  """
  
  use ExUnit.CaseTemplate
  
  alias VsmPhoenix.UserFactory
  alias VsmPhoenix.EventFactory
  alias VsmPhoenix.Auth.Guardian
  
  # Authentication helpers
  
  def create_authenticated_user(role \\ :user) do
    user = UserFactory.insert!(role)
    token = create_jwt_token(user)
    {user, token}
  end
  
  def create_jwt_token(user) do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    token
  end
  
  def create_api_key_user do
    UserFactory.create_user_with_api_key()
  end
  
  def auth_headers(token) do
    [{"authorization", "Bearer #{token}"}]
  end
  
  def api_key_headers(api_key) do
    [{"x-api-key", api_key}]
  end
  
  # Request helpers
  
  def json_request(conn, method, path, params \\ %{}, headers \\ []) do
    conn
    |> put_req_headers(headers)
    |> put_req_header("content-type", "application/json")
    |> request(method, path, Jason.encode!(params))
  end
  
  def authenticated_request(conn, method, path, params \\ %{}, user_role \\ :user) do
    {_user, token} = create_authenticated_user(user_role)
    headers = auth_headers(token)
    json_request(conn, method, path, params, headers)
  end
  
  def api_key_request(conn, method, path, params \\ %{}) do
    {_user, api_key} = create_api_key_user()
    headers = api_key_headers(api_key)
    json_request(conn, method, path, params, headers)
  end
  
  defp request(conn, method, path, body) do
    conn
    |> dispatch(VsmPhoenixWeb.Endpoint, method, path, body)
  end
  
  defp put_req_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {key, value}, acc ->
      put_req_header(acc, key, value)
    end)
  end
  
  # Response helpers
  
  def json_response_body(conn) do
    conn.resp_body |> Jason.decode!()
  end
  
  def assert_json_response(conn, status) do
    assert conn.status == status
    assert get_resp_header(conn, "content-type") |> List.first() =~ "application/json"
    json_response_body(conn)
  end
  
  def assert_unauthorized(conn) do
    assert conn.status == 401
    response = json_response_body(conn)
    assert Map.has_key?(response, "error")
  end
  
  def assert_forbidden(conn) do
    assert conn.status == 403
    response = json_response_body(conn)
    assert Map.has_key?(response, "error")
  end
  
  def assert_rate_limited(conn) do
    assert conn.status == 429
    response = json_response_body(conn)
    assert response["error"] =~ "Rate limit exceeded"
    assert get_resp_header(conn, "retry-after") != []
  end
  
  # VSM-specific helpers
  
  def setup_vsm_mock do
    start_supervised!(VsmPhoenix.Mocks.VSMMock)
    VsmPhoenix.Mocks.VSMMock.reset_all_systems()
  end
  
  def setup_llm_mock do
    VsmPhoenix.Mocks.LLMMock.set_response_mode(:normal)
    VsmPhoenix.Mocks.LLMMock.clear_custom_response()
    VsmPhoenix.Mocks.LLMMock.clear_latency()
  end
  
  def simulate_system_failure(system) do
    VsmPhoenix.Mocks.VSMMock.simulate_system_failure(system)
  end
  
  def simulate_system_recovery(system) do
    VsmPhoenix.Mocks.VSMMock.simulate_system_recovery(system)
  end
  
  def assert_system_healthy(system) do
    status = VsmPhoenix.Mocks.VSMMock.get_system_status(system)
    assert status == :healthy
  end
  
  def assert_viability_above_threshold(threshold \\ 0.7) do
    score = VsmPhoenix.Mocks.VSMMock.get_viability_score()
    assert score >= threshold
  end
  
  # Database helpers
  
  def create_test_events(count \\ 10) do
    EventFactory.create_event_stream(count)
  end
  
  def create_system_events do
    EventFactory.create_system_events()
  end
  
  def truncate_tables do
    Ecto.Adapters.SQL.query!(VsmPhoenix.Repo, "TRUNCATE users CASCADE")
    Ecto.Adapters.SQL.query!(VsmPhoenix.Repo, "TRUNCATE events CASCADE")
    Ecto.Adapters.SQL.query!(VsmPhoenix.Repo, "TRUNCATE security_audit_logs CASCADE")
    Ecto.Adapters.SQL.query!(VsmPhoenix.Repo, "TRUNCATE vsm_metrics CASCADE")
    Ecto.Adapters.SQL.query!(VsmPhoenix.Repo, "TRUNCATE ml_models CASCADE")
    Ecto.Adapters.SQL.query!(VsmPhoenix.Repo, "TRUNCATE api_tokens CASCADE")
  end
  
  # Async testing helpers
  
  def wait_for_async_operation(fun, timeout \\ 5000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    wait_until(fun, deadline)
  end
  
  defp wait_until(fun, deadline) do
    if System.monotonic_time(:millisecond) > deadline do
      raise "Timeout waiting for async operation"
    end
    
    case fun.() do
      true -> :ok
      false -> 
        Process.sleep(50)
        wait_until(fun, deadline)
    end
  end
  
  def eventually(assertion_fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    interval = Keyword.get(opts, :interval, 100)
    
    deadline = System.monotonic_time(:millisecond) + timeout
    eventually_loop(assertion_fun, deadline, interval)
  end
  
  defp eventually_loop(assertion_fun, deadline, interval) do
    if System.monotonic_time(:millisecond) > deadline do
      assertion_fun.()  # Final attempt - let it fail with assertion error
    else
      try do
        assertion_fun.()
      rescue
        _ ->
          Process.sleep(interval)
          eventually_loop(assertion_fun, deadline, interval)
      end
    end
  end
  
  # Performance testing helpers
  
  def measure_response_time(fun) do
    start_time = System.monotonic_time(:microsecond)
    result = fun.()
    end_time = System.monotonic_time(:microsecond)
    duration_ms = (end_time - start_time) / 1000
    {result, duration_ms}
  end
  
  def assert_response_time_under(fun, max_time_ms) do
    {result, actual_time} = measure_response_time(fun)
    assert actual_time < max_time_ms, 
           "Response time #{actual_time}ms exceeded maximum #{max_time_ms}ms"
    result
  end
  
  def load_test(request_fun, concurrent_requests \\ 10) do
    tasks = 
      1..concurrent_requests
      |> Enum.map(fn _ ->
        Task.async(fn ->
          {result, time} = measure_response_time(request_fun)
          %{result: result, response_time: time}
        end)
      end)
    
    results = Task.await_many(tasks, 10_000)
    
    response_times = Enum.map(results, & &1.response_time)
    
    %{
      total_requests: concurrent_requests,
      avg_response_time: Enum.sum(response_times) / length(response_times),
      max_response_time: Enum.max(response_times),
      min_response_time: Enum.min(response_times),
      success_rate: calculate_success_rate(results)
    }
  end
  
  defp calculate_success_rate(results) do
    successful = Enum.count(results, fn %{result: result} ->
      case result do
        %Plug.Conn{status: status} when status < 400 -> true
        _ -> false
      end
    end)
    
    successful / length(results)
  end
end