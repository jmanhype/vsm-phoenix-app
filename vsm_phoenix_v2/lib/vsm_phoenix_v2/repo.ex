defmodule VsmPhoenixV2.Repo do
  use Ecto.Repo,
    otp_app: :vsm_phoenix_v2,
    adapter: Ecto.Adapters.Postgres
end
