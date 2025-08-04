import Config

# Helper function to parse comma-separated chat IDs
parse_chat_list = fn
  nil -> []
  "" -> []
  chat_list ->
    chat_list
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
    |> Enum.filter(& &1)
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it will not be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/vsm_phoenix start
#
# Alternatively, you can use `mix phx.server` or set the PROD_SERVER
# environment variable when compiling the release.
#
#     MIX_ENV=prod mix release --env=prod
#     PROD_SERVER=true _build/prod/rel/vsm_phoenix/bin/vsm_phoenix start

if System.get_env("PHX_SERVER") do
  config :vsm_phoenix, VsmPhoenixWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :vsm_phoenix, VsmPhoenix.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :vsm_phoenix, VsmPhoenixWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :vsm_phoenix, VsmPhoenixWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your endpoint, ensuring
  # no data is ever sent via http, always redirecting to https:
  #
  #     config :vsm_phoenix, VsmPhoenixWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :vsm_phoenix, VsmPhoenix.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.

  # VSM Production Configuration
  config :vsm_phoenix, :vsm,
    # Production settings for optimal performance
    queen: [
      policy_check_interval: String.to_integer(System.get_env("VSM_QUEEN_CHECK_INTERVAL") || "30000"),
      viability_threshold: String.to_float(System.get_env("VSM_VIABILITY_THRESHOLD") || "0.8"),
      intervention_threshold: String.to_float(System.get_env("VSM_INTERVENTION_THRESHOLD") || "0.7")
    ],
    
    intelligence: [
      scan_interval: String.to_integer(System.get_env("VSM_INTELLIGENCE_SCAN_INTERVAL") || "300000"),
      tidewave_enabled: System.get_env("TIDEWAVE_ENABLED") == "true",
      adaptation_timeout: String.to_integer(System.get_env("VSM_ADAPTATION_TIMEOUT") || "600000"),
      learning_rate: String.to_float(System.get_env("VSM_LEARNING_RATE") || "0.05")
    ],
    
    control: [
      optimization_interval: String.to_integer(System.get_env("VSM_CONTROL_OPTIMIZATION_INTERVAL") || "60000"),
      resource_thresholds: %{
        compute: String.to_float(System.get_env("VSM_COMPUTE_THRESHOLD") || "0.75"),
        memory: String.to_float(System.get_env("VSM_MEMORY_THRESHOLD") || "0.8"),
        network: String.to_float(System.get_env("VSM_NETWORK_THRESHOLD") || "0.65"),
        storage: String.to_float(System.get_env("VSM_STORAGE_THRESHOLD") || "0.85")
      }
    ],
    
    coordinator: [
      sync_check_interval: String.to_integer(System.get_env("VSM_COORDINATOR_SYNC_INTERVAL") || "15000"),
      oscillation_detection_window: String.to_integer(System.get_env("VSM_OSCILLATION_WINDOW") || "10000"),
      max_message_frequency: String.to_integer(System.get_env("VSM_MAX_MESSAGE_FREQ") || "50")
    ],
    
    operations: [
      health_check_interval: String.to_integer(System.get_env("VSM_OPERATIONS_HEALTH_INTERVAL") || "45000"),
      max_processing_time: String.to_integer(System.get_env("VSM_MAX_PROCESSING_TIME") || "500"),
      customer_response_target: String.to_integer(System.get_env("VSM_CUSTOMER_RESPONSE_TARGET") || "200")
    ],
    
    telegram: [
      bot_token: System.get_env("TELEGRAM_BOT_TOKEN"),
      webhook_mode: System.get_env("TELEGRAM_WEBHOOK_MODE") == "true",
      webhook_url: System.get_env("TELEGRAM_WEBHOOK_URL"),
      authorized_chats: parse_chat_list.(System.get_env("TELEGRAM_AUTHORIZED_CHATS")),
      admin_chats: parse_chat_list.(System.get_env("TELEGRAM_ADMIN_CHATS")),
      rate_limit: String.to_integer(System.get_env("TELEGRAM_RATE_LIMIT") || "30"),
      command_timeout: String.to_integer(System.get_env("TELEGRAM_COMMAND_TIMEOUT") || "5000")
    ]

  # Tidewave Production Configuration
  if System.get_env("TIDEWAVE_ENABLED") == "true" do
    config :tidewave,
      endpoint: System.get_env("TIDEWAVE_ENDPOINT") || "https://api.tidewave.io",
      api_key: System.get_env("TIDEWAVE_API_KEY") || raise("TIDEWAVE_API_KEY is required when Tidewave is enabled"),
      timeout: String.to_integer(System.get_env("TIDEWAVE_TIMEOUT") || "30000")
  end
end