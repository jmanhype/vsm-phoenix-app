defmodule VsmPhoenixWeb.EventsHTML do
  @moduledoc """
  This module contains pages rendered by EventsController.
  """
  use VsmPhoenixWeb, :html

  embed_templates "events_html/*"

  # Helper functions for dashboard template
  def event_color(event_type) do
    case event_type do
      "chaos" -> "bg-red-400"
      "quantum" -> "bg-blue-400"
      "emergent" -> "bg-purple-400"
      "meta_vsm" -> "bg-green-400"
      "algedonic" -> "bg-yellow-400"
      "system" -> "bg-gray-400"
      _ -> "bg-white"
    end
  end

  def trend_color(direction) do
    case direction do
      :up -> "text-green-400"
      :down -> "text-red-400"
      :stable -> "text-gray-400"
      _ -> "text-gray-400"
    end
  end

  def trend_icon(direction) do
    case direction do
      :up -> "↗"
      :down -> "↘"
      :stable -> "→"
      _ -> "•"
    end
  end
end