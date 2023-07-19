import Config

config :fork_with_flags, :redis,
  database: 5

config :logger, level: :error


if System.get_env("PERSISTENCE") == "ecto" do
  config :fork_with_flags, ForkWithFlags.Dev.EctoRepo,
    database: "fun_with_flags_test",
    pool: Ecto.Adapters.SQL.Sandbox,
    ownership_timeout: 10 * 60 * 1000
end
