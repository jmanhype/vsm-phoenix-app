defmodule TestConsumer do
  def start do
    {:ok, connection} = AMQP.Connection.open()
    {:ok, channel} = AMQP.Channel.open(connection)
    
    # Declare a test queue
    {:ok, %{queue: queue_name}} = AMQP.Queue.declare(channel, "", exclusive: true)
    
    # Bind to algedonic exchange
    :ok = AMQP.Queue.bind(channel, queue_name, "vsm.algedonic")
    
    # Start consuming
    {:ok, _consumer_tag} = AMQP.Basic.consume(channel, queue_name, nil, no_ack: true)
    
    IO.puts("Test consumer started, listening to vsm.algedonic exchange on queue: #{queue_name}")
    
    # Receive messages
    receive_messages()
  end
  
  defp receive_messages do
    receive do
      {:basic_deliver, payload, _meta} ->
        IO.puts("RECEIVED MESSAGE: #{payload}")
        receive_messages()
    end
  end
end

# Start the test consumer
TestConsumer.start()