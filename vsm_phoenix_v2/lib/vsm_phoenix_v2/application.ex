defmodule VsmPhoenixV2.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      VsmPhoenixV2Web.Telemetry,
      VsmPhoenixV2.Repo,
      {DNSCluster, query: Application.get_env(:vsm_phoenix_v2, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: VsmPhoenixV2.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: VsmPhoenixV2.Finch},
      # Start a worker by calling: VsmPhoenixV2.Worker.start_link(arg)
      # {VsmPhoenixV2.Worker, arg},
      # Start to serve requests, typically the last entry
      VsmPhoenixV2Web.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: VsmPhoenixV2.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    VsmPhoenixV2Web.Endpoint.config_change(changed, removed)
    :ok
  end
end
