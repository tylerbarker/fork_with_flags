defmodule ForkWithFlags.TestUtils do
  alias ForkWithFlags.Config
  import ExUnit.Assertions, only: [assert: 1]

  @test_db 5
  @redis ForkWithFlags.Store.Persistent.Redis

  # Since the flags are saved on shared storage (ETS and
  # Redis), in order to keep the tests isolated _and_ async
  # each test must use unique flag names. Not doing so would
  # cause some tests to override other tests flag values.
  #
  # This method should _never_ be used at runtime because
  # atoms are not garbage collected.
  #
  def unique_atom do
    String.to_atom(random_string())
  end

  def random_string do
    :crypto.strong_rand_bytes(7)
    |> Base.encode32(padding: false, case: :lower)
  end

  def use_redis_test_db do
    Redix.command!(@redis, ["SELECT", @test_db])
  end

  def clear_test_db do
    unless Config.persist_in_ecto? do
      use_redis_test_db()

      Redix.command!(@redis, ["DEL", "fun_with_flags"])
      Redix.command!(@redis, ["KEYS", "fun_with_flags:*"])
      |> delete_keys()
    end
  end

  defp delete_keys([]), do: 0
  defp delete_keys(keys) do
    Redix.command!(@redis, ["DEL" | keys])
  end

  def clear_cache do
    if Config.cache? do
      ForkWithFlags.Store.Cache.flush()
    end
  end

  defmacro timetravel([by: offset], [do: body]) do
    quote do
      fake_now = ForkWithFlags.Timestamps.now + unquote(offset)
      # IO.puts("now:      #{ForkWithFlags.Timestamps.now}")
      # IO.puts("offset:   #{unquote(offset)}")
      # IO.puts("fake_now: #{fake_now}")

      with_mock(ForkWithFlags.Timestamps, [
        now: fn() ->
          fake_now
        end,
        expired?: fn(timestamp, ttl) ->
          :meck.passthrough([timestamp, ttl])
        end
      ]) do
        unquote(body)
      end
    end
  end

  def kill_process(name) do
    true = GenServer.whereis(name) |> Process.exit(:kill)
  end

  def configure_redis_with(conf) do
    Application.put_all_env(fork_with_flags: [redis: conf])
    assert ^conf = Application.get_env(:fork_with_flags, :redis)
  end

  def ensure_default_redis_config_in_app_env do
    assert match?([database: 5], Application.get_env(:fork_with_flags, :redis))
  end

  def reset_app_env_to_default_redis_config do
    configure_redis_with([database: 5])
  end
end
