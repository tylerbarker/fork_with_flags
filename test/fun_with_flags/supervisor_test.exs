defmodule ForkWithFlags.SupervisorTest do
  use ForkWithFlags.TestCase, async: false

  alias ForkWithFlags.Config

  test "the auto-generated child_spec/1" do
    expected = %{
      id: ForkWithFlags.Supervisor,
      start: {ForkWithFlags.Supervisor, :start_link, [nil]},
      type: :supervisor
    }

    assert ^expected = ForkWithFlags.Supervisor.child_spec(nil)
  end

  describe "initializing the config for the children" do
    @tag :redis_persistence
    @tag :redis_pubsub
    test "with Redis persistence and Redis PubSub" do
      expected = {
        :ok,
        {
          %{intensity: 3, period: 5, strategy: :one_for_one},
          [
            %{
              id: ForkWithFlags.Store.Cache,
              restart: :permanent,
              start: {ForkWithFlags.Store.Cache, :start_link, []},
              type: :worker
            },
            %{
              id: Redix,
              start: {Redix, :start_link,
               [
                 [
                   host: "localhost",
                   port: 6379,
                   database: 5,
                   name: ForkWithFlags.Store.Persistent.Redis,
                   sync_connect: false
                 ]
               ]},
              type: :worker
            },
            %{
              id: ForkWithFlags.Notifications.Redis,
              restart: :permanent,
              start: {ForkWithFlags.Notifications.Redis, :start_link, [
                [host: "localhost", port: 6379, database: 5, name: :fun_with_flags_notifications, sync_connect: false]
              ]},
              type: :worker
            }
          ]
        }
      }

      assert ^expected = ForkWithFlags.Supervisor.init(nil)
    end

    @tag :redis_persistence
    @tag :phoenix_pubsub
    test "with Redis persistence and Phoenix PubSub" do
      expected = {
        :ok,
        {
          %{intensity: 3, period: 5, strategy: :one_for_one},
          [
            %{
              id: ForkWithFlags.Store.Cache,
              restart: :permanent,
              start: {ForkWithFlags.Store.Cache, :start_link, []},
              type: :worker
            },
            %{
              id: Redix,
              start: {Redix, :start_link,
               [
                 [
                   host: "localhost",
                   port: 6379,
                   database: 5,
                   name: ForkWithFlags.Store.Persistent.Redis,
                   sync_connect: false
                 ]
               ]},
              type: :worker
            },
            %{
              id: ForkWithFlags.Notifications.PhoenixPubSub,
              restart: :permanent,
              start: {ForkWithFlags.Notifications.PhoenixPubSub, :start_link, []},
              type: :worker
            }
          ]
        }
      }

      assert ^expected = ForkWithFlags.Supervisor.init(nil)
    end

    @tag :ecto_persistence
    @tag :phoenix_pubsub
    test "with Ecto persistence and Phoenix PubSub" do
      expected = {
        :ok,
        {
          %{intensity: 3, period: 5, strategy: :one_for_one},
          [
            %{
              id: ForkWithFlags.Store.Cache,
              restart: :permanent,
              start: {ForkWithFlags.Store.Cache, :start_link, []},
              type: :worker
            },
            %{
              id: ForkWithFlags.Notifications.PhoenixPubSub,
              restart: :permanent,
              start: {ForkWithFlags.Notifications.PhoenixPubSub, :start_link, []},
              type: :worker
            }
          ]
        }
      }

      assert ^expected = ForkWithFlags.Supervisor.init(nil)
    end
  end


  describe "initializing the config for the children (no cache)" do
    setup do
      # Capture the original cache config
      original_cache_config = Config.ets_cache_config()

      # Disable the cache for these tests.
      Application.put_all_env(fork_with_flags: [cache: [
        enabled: false, ttl: original_cache_config[:ttl]
      ]])

      # Restore the original config
      on_exit fn ->
        Application.put_all_env(fork_with_flags: [cache: original_cache_config])
        assert ^original_cache_config = Config.ets_cache_config()
      end
    end

    @tag :redis_persistence
    @tag :redis_pubsub
    test "with Redis persistence and Redis PubSub, no cache" do
      expected = {
        :ok,
        {
          %{intensity: 3, period: 5, strategy: :one_for_one},
          [
            %{
              id: Redix,
              start: {Redix, :start_link,
               [
                 [
                   host: "localhost",
                   port: 6379,
                   database: 5,
                   name: ForkWithFlags.Store.Persistent.Redis,
                   sync_connect: false
                 ]
               ]},
              type: :worker
            }
          ]
        }
      }

      assert ^expected = ForkWithFlags.Supervisor.init(nil)
    end

    @tag :redis_persistence
    @tag :phoenix_pubsub
    test "with Redis persistence and Phoenix PubSub, no cache" do
      expected = {
        :ok,
        {
          %{intensity: 3, period: 5, strategy: :one_for_one},
          [
            %{
              id: Redix,
              start: {Redix, :start_link,
               [
                 [
                   host: "localhost",
                   port: 6379,
                   database: 5,
                   name: ForkWithFlags.Store.Persistent.Redis,
                   sync_connect: false
                 ]
               ]},
              type: :worker
            }
          ]
        }
      }

      assert ^expected = ForkWithFlags.Supervisor.init(nil)
    end

    @tag :ecto_persistence
    @tag :phoenix_pubsub
    test "with Ecto persistence and Phoenix PubSub, no cache" do
      expected = {
        :ok,
        {
          %{intensity: 3, period: 5, strategy: :one_for_one},
          []
        }
      }

      assert ^expected = ForkWithFlags.Supervisor.init(nil)
    end
  end
end
