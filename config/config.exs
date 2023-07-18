import Config

# config :fork_with_flags, :persistence,
#   [adapter: ForkWithFlags.Store.Persistent.Redis]
# config :fork_with_flags, :cache_bust_notifications,
#   [enabled: true, adapter: ForkWithFlags.Notifications.Redis]


# -------------------------------------------------
# Extract from the ENV

with_cache =
  case System.get_env("CACHE_ENABLED") do
    "false" -> false
    "0"     -> false
    _       -> true # default
  end

with_phx_pubsub =
  case System.get_env("PUBSUB_BROKER") do
    "phoenix_pubsub" -> true
    _ -> false
  end

with_ecto =
  case System.get_env("PERSISTENCE") do
    "ecto" -> true
    _      -> false # default
  end


# -------------------------------------------------
# Configuration

config :fork_with_flags, :cache,
  enabled: with_cache,
  ttl: 60


if with_phx_pubsub do
  config :fork_with_flags, :cache_bust_notifications, [
    adapter: ForkWithFlags.Notifications.PhoenixPubSub,
    client: :fwf_test
  ]
end


if with_ecto do
  # this library's config
  config :fork_with_flags, :persistence,
    adapter: ForkWithFlags.Store.Persistent.Ecto,
    repo: ForkWithFlags.Dev.EctoRepo

  # To test the compile-time config warnings.
  # config :fork_with_flags, :persistence,
  #   ecto_table_name: System.get_env("ECTO_TABLE_NAME", "fun_with_flags_toggles")

  # ecto's config
  config :fork_with_flags, ecto_repos: [ForkWithFlags.Dev.EctoRepo]

  config :fork_with_flags, ForkWithFlags.Dev.EctoRepo,
    database: "fun_with_flags_dev",
    hostname: "localhost",
    pool_size: 10

  case System.get_env("RDBMS") do
    "mysql" ->
      config :fork_with_flags, ForkWithFlags.Dev.EctoRepo,
        username: "root",
        password: "root"
    "sqlite" ->
      config :fork_with_flags, ForkWithFlags.Dev.EctoRepo,
        username: "sqlite",
        password: "sqlite"
    _ ->
      config :fork_with_flags, ForkWithFlags.Dev.EctoRepo,
        username: "postgres",
        password: "postgres"
  end
end

# -------------------------------------------------
# Import
#
case config_env() do
  :test -> import_config "test.exs"
  _     -> nil
end
