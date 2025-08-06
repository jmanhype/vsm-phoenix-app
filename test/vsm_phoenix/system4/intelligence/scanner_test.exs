defmodule VsmPhoenix.System4.Intelligence.ScannerTest do
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.System4.Intelligence.Scanner
  
  setup do
    {:ok, scanner} = Scanner.start_link(name: nil)
    %{scanner: scanner}
  end
  
  describe "scan_environment/1" do
    test "performs full environmental scan", %{scanner: scanner} do
      {:ok, scan_data} = GenServer.call(scanner, {:scan_environment, :full})
      
      assert Map.has_key?(scan_data, :market_signals)
      assert Map.has_key?(scan_data, :technology_trends)
      assert Map.has_key?(scan_data, :regulatory_updates)
      assert Map.has_key?(scan_data, :competitive_moves)
      assert Map.has_key?(scan_data, :timestamp)
      
      assert is_list(scan_data.market_signals)
      assert length(scan_data.market_signals) > 0
    end
    
    test "performs scheduled scan", %{scanner: scanner} do
      {:ok, scan_data} = GenServer.call(scanner, {:scan_environment, :scheduled})
      
      assert scan_data.scope == :scheduled
    end
  end
  
  describe "collect_market_signals/0" do
    test "returns market signals", %{scanner: scanner} do
      {:ok, signals} = GenServer.call(scanner, :collect_market_signals)
      
      assert is_list(signals)
      assert Enum.all?(signals, fn signal ->
        Map.has_key?(signal, :signal) and
        Map.has_key?(signal, :strength) and
        Map.has_key?(signal, :source)
      end)
    end
  end
  
  describe "collect_technology_trends/0" do
    test "returns technology trends", %{scanner: scanner} do
      {:ok, trends} = GenServer.call(scanner, :collect_technology_trends)
      
      assert is_list(trends)
      assert Enum.all?(trends, fn trend ->
        Map.has_key?(trend, :trend) and
        Map.has_key?(trend, :impact) and
        Map.has_key?(trend, :timeline)
      end)
    end
  end
  
  describe "get_tidewave_status/0" do
    test "returns connection status", %{scanner: scanner} do
      status = GenServer.call(scanner, :get_tidewave_status)
      
      assert status in [:connected, :disconnected]
    end
  end
  
  describe "scheduled scanning" do
    @tag :skip
    test "automatically performs scheduled scans" do
      # This test would verify scheduled scanning works
      # Skip for now as it requires waiting for scheduled events
    end
  end
end