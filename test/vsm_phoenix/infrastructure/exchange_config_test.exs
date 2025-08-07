defmodule VsmPhoenix.Infrastructure.ExchangeConfigTest do
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.Infrastructure.ExchangeConfig
  
  describe "get_exchange_name/1" do
    test "returns default exchange name for known exchange" do
      # Uses default configuration since no env vars set
      assert ExchangeConfig.get_exchange_name(:algedonic) == "vsm.algedonic"
      assert ExchangeConfig.get_exchange_name(:commands) == "vsm.commands"
      assert ExchangeConfig.get_exchange_name(:control) == "vsm.control"
    end
    
    test "returns default value for unknown exchange keys" do
      # Should return "vsm.unknown" for unknown keys, not raise
      assert ExchangeConfig.get_exchange_name(:unknown_exchange) == "vsm.unknown"
    end
    
    test "handles string keys by converting to atoms" do
      assert ExchangeConfig.get_exchange_name("algedonic") == "vsm.algedonic"
    end
    
    test "returns string as-is if not a known atom" do
      assert ExchangeConfig.get_exchange_name("custom.exchange.name") == "custom.exchange.name"
    end
  end
  
  describe "agent_exchange/2" do
    test "creates agent-specific exchange name" do
      result = ExchangeConfig.agent_exchange("agent123", "telemetry")
      assert result == "vsm.s1.agent123.telemetry"
    end
    
    test "handles different types" do
      assert ExchangeConfig.agent_exchange("worker1", "status") == "vsm.s1.worker1.status"
      assert ExchangeConfig.agent_exchange("sensor2", "data") == "vsm.s1.sensor2.data"
    end
  end
  
  describe "all_exchanges/0" do
    test "returns all configured exchanges with types" do
      exchanges = ExchangeConfig.all_exchanges()
      
      # Should return list of {exchange_name, type} tuples
      assert is_list(exchanges)
      
      # Find algedonic exchange in the list
      algedonic_entry = Enum.find(exchanges, fn {name, _type} -> 
        name == "vsm.algedonic" 
      end)
      assert algedonic_entry == {"vsm.algedonic", :fanout}
      
      # Find commands exchange
      commands_entry = Enum.find(exchanges, fn {name, _type} -> 
        name == "vsm.commands" 
      end)
      assert commands_entry == {"vsm.commands", :topic}
    end
  end
  
  describe "environment prefix integration" do
    setup do
      # Save original env vars
      original_prefix = System.get_env("VSM_ENV_PREFIX")
      original_algedonic = System.get_env("VSM_EXCHANGE_ALGEDONIC")
      
      on_exit(fn ->
        if original_prefix do
          System.put_env("VSM_ENV_PREFIX", original_prefix)
        else
          System.delete_env("VSM_ENV_PREFIX")
        end
        
        if original_algedonic do
          System.put_env("VSM_EXCHANGE_ALGEDONIC", original_algedonic)
        else
          System.delete_env("VSM_EXCHANGE_ALGEDONIC")
        end
      end)
    end
    
    test "uses environment prefix when configured" do
      System.put_env("VSM_ENV_PREFIX", "staging")
      
      result = ExchangeConfig.get_exchange_name(:algedonic)
      assert result == "staging.algedonic"
    end
    
    test "uses specific exchange environment variable when set" do
      System.put_env("VSM_EXCHANGE_ALGEDONIC", "custom.algedonic.exchange")
      
      result = ExchangeConfig.get_exchange_name(:algedonic)
      assert result == "custom.algedonic.exchange"
    end
  end
end