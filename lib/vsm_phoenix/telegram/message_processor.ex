defmodule VsmPhoenix.Telegram.MessageProcessor do
  @moduledoc """
  SOLID: Single Responsibility - ONLY processes messages
  DRY: Eliminates duplicate message parsing/routing logic
  Interface Segregation: Separate interfaces for different message types
  """
  
  use VsmPhoenix.Behaviors.Loggable, prefix: "💬 MessageProcessor:"
  
  # DRY: Message type definitions in one place
  @message_types %{
    text: :process_text,
    photo: :process_photo,
    document: :process_document,
    voice: :process_voice,
    callback_query: :process_callback,
    inline_query: :process_inline
  }
  
  @command_pattern ~r/^\/(\w+)(?:\s+(.*))?$/
  
  # Protocol for extensible message handling (Open/Closed Principle)
  defprotocol Processable do
    def process(message, context)
  end
  
  # DRY: Single entry point for all messages
  def process_update(update, context) do
    result = update
    |> extract_message()
    |> route_message(context)
    
    # Log and return the result
    case result do
      {:ok, processed} -> 
        log_info("Processed update: #{inspect(processed.type)}")
        {:ok, processed}
      error -> 
        log_error("Failed to process update: #{inspect(error)}")
        error
    end
  end
  
  # DRY: Extract message from various update types
  defp extract_message(%{"message" => msg}), do: {:message, msg}
  defp extract_message(%{"edited_message" => msg}), do: {:edited, msg}
  defp extract_message(%{"callback_query" => query}), do: {:callback, query}
  defp extract_message(%{"inline_query" => query}), do: {:inline, query}
  defp extract_message(_), do: {:unknown, nil}
  
  # DRY: Single routing logic
  defp route_message({:message, msg}, context) do
    cond do
      msg["text"] && String.starts_with?(msg["text"], "/") ->
        process_command(msg, context)
      msg["text"] ->
        process_text(msg, context)
      msg["photo"] ->
        process_photo(msg, context)
      msg["document"] ->
        process_document(msg, context)
      msg["voice"] ->
        process_voice(msg, context)
      true ->
        {:error, :unsupported_message_type}
    end
  end
  
  defp route_message({:callback, query}, context) do
    process_callback(query, context)
  end
  
  defp route_message({:inline, query}, context) do
    process_inline(query, context)
  end
  
  defp route_message({_, _}, _context) do
    {:error, :unknown_update_type}
  end
  
  # DRY: Command parsing in one place
  defp process_command(%{"text" => text} = msg, context) do
    case Regex.run(@command_pattern, text) do
      [_, command, args] ->
        handle_command(command, args, msg, context)
      _ ->
        {:error, :invalid_command}
    end
  end
  
  # Command handlers - easily extensible (Open/Closed)
  defp handle_command("start", _args, msg, context) do
    {:ok, %{
      type: :command,
      command: :start,
      chat_id: msg["chat"]["id"],
      user: msg["from"],
      response: "Welcome! I'm your VSM assistant."
    }}
  end
  
  defp handle_command("help", _args, msg, context) do
    {:ok, %{
      type: :command,
      command: :help,
      chat_id: msg["chat"]["id"],
      response: build_help_text(context)
    }}
  end
  
  defp handle_command("status", _args, msg, context) do
    {:ok, %{
      type: :command,
      command: :status,
      chat_id: msg["chat"]["id"],
      needs_processing: true
    }}
  end
  
  defp handle_command(cmd, args, msg, context) do
    {:ok, %{
      type: :command,
      command: String.to_atom(cmd),
      args: args,
      chat_id: msg["chat"]["id"],
      needs_processing: true
    }}
  end
  
  # Message type handlers
  defp process_text(%{"text" => text} = msg, _context) do
    {:ok, %{
      type: :text,
      content: text,
      chat_id: msg["chat"]["id"],
      user: msg["from"],
      needs_llm: true
    }}
  end
  
  defp process_photo(msg, _context) do
    {:ok, %{
      type: :photo,
      photos: msg["photo"],
      caption: msg["caption"],
      chat_id: msg["chat"]["id"]
    }}
  end
  
  defp process_document(msg, _context) do
    {:ok, %{
      type: :document,
      document: msg["document"],
      chat_id: msg["chat"]["id"]
    }}
  end
  
  defp process_voice(msg, _context) do
    {:ok, %{
      type: :voice,
      voice: msg["voice"],
      chat_id: msg["chat"]["id"],
      needs_transcription: true
    }}
  end
  
  defp process_callback(query, _context) do
    {:ok, %{
      type: :callback,
      data: query["data"],
      callback_id: query["id"],
      from: query["from"],
      message: query["message"]
    }}
  end
  
  defp process_inline(query, _context) do
    {:ok, %{
      type: :inline,
      query: query["query"],
      query_id: query["id"],
      from: query["from"]
    }}
  end
  
  # DRY: Help text generation
  defp build_help_text(context) do
    """
    Available commands:
    /start - Start the bot
    /help - Show this help
    /status - Check system status
    #{context[:extra_commands] || ""}
    """
  end
end