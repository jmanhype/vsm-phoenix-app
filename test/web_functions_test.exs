defmodule WebFunctionsTest do
  use ExUnit.Case
  
  describe "VsmPhoenixWeb functions" do
    test "static_paths returns correct paths" do
      paths = VsmPhoenixWeb.static_paths()
      
      assert is_list(paths)
      assert "assets" in paths
      assert "fonts" in paths
      assert "images" in paths
      assert "favicon.ico" in paths
      assert "robots.txt" in paths
      assert length(paths) == 5
    end
    
    test "router macro returns quoted expression" do
      result = VsmPhoenixWeb.router()
      assert is_tuple(result)
      assert elem(result, 0) == :quote
    end
    
    test "channel macro returns quoted expression" do
      result = VsmPhoenixWeb.channel()
      assert is_tuple(result)
      assert elem(result, 0) == :quote
    end
    
    test "controller macro returns quoted expression" do
      result = VsmPhoenixWeb.controller()
      assert is_tuple(result)
      assert elem(result, 0) == :quote
    end
    
    test "live_view macro returns quoted expression" do
      result = VsmPhoenixWeb.live_view()
      assert is_tuple(result)
      assert elem(result, 0) == :quote
    end
    
    test "live_component macro returns quoted expression" do
      result = VsmPhoenixWeb.live_component()
      assert is_tuple(result)
      assert elem(result, 0) == :quote
    end
    
    test "html macro returns quoted expression" do
      result = VsmPhoenixWeb.html()
      assert is_tuple(result)
      assert elem(result, 0) == :quote
    end
    
    test "verified_routes macro returns quoted expression" do
      result = VsmPhoenixWeb.verified_routes()
      assert is_tuple(result)
      assert elem(result, 0) == :quote
    end
  end
  
  describe "Telemetry metrics" do
    test "metrics returns list of telemetry metrics" do
      metrics = VsmPhoenixWeb.Telemetry.metrics()
      
      assert is_list(metrics)
      assert length(metrics) > 0
      
      # Each metric should be a Telemetry.Metrics struct
      Enum.each(metrics, fn metric ->
        assert is_struct(metric)
        assert Map.has_key?(metric, :__struct__)
      end)
    end
  end
  
  describe "Config and environment functions" do
    test "Mix.env returns test environment" do
      assert Mix.env() == :test
    end
    
    test "can check if modules are compiled" do
      compiled_modules = [
        VsmPhoenix.Repo,
        VsmPhoenixWeb,
        VsmPhoenixWeb.Endpoint,
        VsmPhoenixWeb.Router
      ]
      
      Enum.each(compiled_modules, fn mod ->
        assert Code.ensure_compiled?(mod)
      end)
    end
  end
  
  describe "Module attributes and metadata" do
    test "modules have module info" do
      modules = [
        VsmPhoenix.Repo,
        VsmPhoenixWeb,
        VsmPhoenixWeb.Endpoint
      ]
      
      Enum.each(modules, fn mod ->
        info = mod.module_info()
        assert is_list(info)
        assert Keyword.has_key?(info, :module)
        assert Keyword.has_key?(info, :exports)
      end)
    end
  end
  
  describe "Phoenix configuration" do
    test "Endpoint has configuration" do
      # Check basic endpoint config exists
      assert is_atom(VsmPhoenixWeb.Endpoint)
      
      # Endpoint should have these standard Phoenix functions
      assert function_exported?(VsmPhoenixWeb.Endpoint, :url, 0)
      assert function_exported?(VsmPhoenixWeb.Endpoint, :path, 1)
      assert function_exported?(VsmPhoenixWeb.Endpoint, :static_url, 0)
    end
    
    test "Router has routes" do
      # Router should export __routes__
      assert function_exported?(VsmPhoenixWeb.Router, :__routes__, 0)
      
      routes = VsmPhoenixWeb.Router.__routes__()
      assert is_list(routes)
      
      # Each route should have standard fields
      if length(routes) > 0 do
        route = hd(routes)
        assert is_map(route)
        assert Map.has_key?(route, :verb)
        assert Map.has_key?(route, :path)
      end
    end
  end
end