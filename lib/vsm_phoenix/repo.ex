defmodule VsmPhoenix.Repo do
  use Ecto.Repo,
    otp_app: :vsm_phoenix,
    adapter: Ecto.Adapters.Postgres
end