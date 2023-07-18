defmodule ForkWithFlagsTest do
  use ForkWithFlags.TestCase, async: false
  import ForkWithFlags.TestUtils
  import Mock

  @moduletag :integration
  doctest ForkWithFlags

  setup_all do
    on_exit(__MODULE__, fn() ->
      clear_test_db()
      clear_cache()
    end)
    :ok
  end

  setup do
    clear_test_db()
    clear_cache()
    :ok
  end

  describe "enabled?(name)" do
    test "it returns false for non existing feature flags" do
      flag_name = unique_atom()
      assert false == ForkWithFlags.enabled?(flag_name)
    end

    test "it returns false for a disabled feature flag" do
      flag_name = unique_atom()
      ForkWithFlags.disable(flag_name)
      assert false == ForkWithFlags.enabled?(flag_name)
    end

    test "it returns true for an enabled feature flag" do
      flag_name = unique_atom()
      ForkWithFlags.enable(flag_name)
      assert true == ForkWithFlags.enabled?(flag_name)
    end

    test "if the store raises an error, it lets it bubble up" do
      name = unique_atom()
      store = ForkWithFlags.compiled_store()

      with_mock(store, [], lookup: fn(^name) -> raise(RuntimeError, "mocked exception") end) do
        assert_raise RuntimeError, "mocked exception", fn() ->
          ForkWithFlags.enabled?(name)
        end
      end
    end
  end


  describe "enabled?(name, for: item)" do
    setup do
      scrooge = %ForkWithFlags.TestUser{id: 1, email: "scrooge@mcduck.pdp", groups: [:ducks, :billionaires]}
      donald = %ForkWithFlags.TestUser{id: 2, email: "donald@duck.db", groups: [:ducks, :super_heroes]}
      {:ok, scrooge: scrooge, donald: donald, flag_name: unique_atom()}
    end

    test "it returns false for non existing feature flags", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      refute ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
    end


    # actors ------------------------------------

    test "it returns true for an enabled actor even though the flag doesn't have a general value,
          while other actors fallback to the default (false)", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      ForkWithFlags.enable(flag_name, for_actor: scrooge)
      refute ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
    end

    test "it returns true for an enabled actor even though the flag is disabled, while other
          actors fallback to the boolean gate (false)", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      ForkWithFlags.enable(flag_name, for_actor: scrooge)
      ForkWithFlags.disable(flag_name)
      refute ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
    end

    test "it returns false for a disabled actor even though the flag is enabled, while other
          actors fallback to the boolean gate (true)", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      ForkWithFlags.disable(flag_name, for_actor: donald)
      ForkWithFlags.enable(flag_name)
      assert ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
    end

    test "more than one actor can be enabled", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      ForkWithFlags.disable(flag_name)
      ForkWithFlags.enable(flag_name, for_actor: scrooge)
      ForkWithFlags.enable(flag_name, for_actor: donald)
      refute ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      assert ForkWithFlags.enabled?(flag_name, for: donald)
    end

    test "more than one actor can be disabled", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      ForkWithFlags.enable(flag_name)
      ForkWithFlags.disable(flag_name, for_actor: scrooge)
      ForkWithFlags.disable(flag_name, for_actor: donald)
      assert ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
    end

    # groups ------------------------------------

    test "it returns true for an item that belongs to an enabled group even though the flag doesn't have a general value,
          while other items fallback to the default (false)", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      ForkWithFlags.enable(flag_name, for_group: :billionaires)
      refute ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
    end

    test "it returns true for an item that belongs to an enabled group even though the flag is disabled, while other
          items fallback to the boolean gate (false)", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      ForkWithFlags.enable(flag_name, for_group: :billionaires)
      ForkWithFlags.disable(flag_name)
      refute ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
    end

    test "it returns false for an item that belongs to a disabled group even though the flag is enabled, while other
          items fallback to the boolean gate (true)", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      ForkWithFlags.disable(flag_name, for_group: :super_heroes)
      ForkWithFlags.enable(flag_name)
      assert ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
    end

    test "more than one group can be enabled", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      ForkWithFlags.disable(flag_name)
      ForkWithFlags.enable(flag_name, for_group: :super_heroes)
      ForkWithFlags.enable(flag_name, for_group: :villains)
      evron = %ForkWithFlags.TestUser{name: "Evron", groups: [:aliens, :villains]}
      batman = %ForkWithFlags.TestUser{name: "Batman", groups: [:humans, :super_heroes]}


      refute ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: scrooge)
      assert ForkWithFlags.enabled?(flag_name, for: donald)
      assert ForkWithFlags.enabled?(flag_name, for: evron)
      assert ForkWithFlags.enabled?(flag_name, for: batman)
    end

    test "more than one group can be disabled", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      ForkWithFlags.enable(flag_name)
      ForkWithFlags.disable(flag_name, for_group: :super_heroes)
      ForkWithFlags.disable(flag_name, for_group: :villains)
      evron = %ForkWithFlags.TestUser{name: "Evron", groups: [:aliens, :villains]}
      batman = %ForkWithFlags.TestUser{name: "Batman", groups: [:humans, :super_heroes]}


      assert ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
      refute ForkWithFlags.enabled?(flag_name, for: evron)
      refute ForkWithFlags.enabled?(flag_name, for: batman)
    end

    # percentage of actors ------------------------------------
    #
    # ForkWithFlags.Actor.Percentage.score scrooge, :potato
    # 0.72467041015625
    # ForkWithFlags.Actor.Percentage.score donald, :potato
    # 0.3559112548828125

    test "when flag doesn't have a general value, it returns true and false for actors based on their scores",
         %{scrooge: scrooge, donald: donald} do
      ForkWithFlags.clear(:potato)
      ForkWithFlags.enable(:potato, for_percentage_of: {:actors, 0.36})
      refute ForkWithFlags.enabled?(:potato)
      refute ForkWithFlags.enabled?(:potato, for: scrooge)
      assert ForkWithFlags.enabled?(:potato, for: donald)
    end

    test "when flag is disabled, it returns true and false for actors based on their scores",
         %{scrooge: scrooge, donald: donald} do
      ForkWithFlags.disable(:potato)
      ForkWithFlags.enable(:potato, for_percentage_of: {:actors, 0.36})
      refute ForkWithFlags.enabled?(:potato)
      refute ForkWithFlags.enabled?(:potato, for: scrooge)
      assert ForkWithFlags.enabled?(:potato, for: donald)
    end

    test "when the flag is fully enabled, it ignores the percentage_of_actors gate",
         %{scrooge: scrooge, donald: donald} do
      ForkWithFlags.enable(:potato)
      ForkWithFlags.enable(:potato, for_percentage_of: {:actors, 0.01}) # disabled for both
      assert ForkWithFlags.enabled?(:potato)
      assert ForkWithFlags.enabled?(:potato, for: scrooge)
      assert ForkWithFlags.enabled?(:potato, for: donald)
    end
  end


  describe "enabling and disabling flags" do
    setup do
      scrooge = %ForkWithFlags.TestUser{id: 1, email: "scrooge@mcduck.pdp", groups: [:ducks, :billionaires]}
      donald = %ForkWithFlags.TestUser{id: 2, email: "donald@duck.db", groups: [:ducks, :super_heroes]}
      mickey = %ForkWithFlags.TestUser{id: 3, email: "mickey@mouse.tp", groups: [:mice]}
      {:ok, scrooge: scrooge, donald: donald, mickey: mickey, flag_name: unique_atom()}
    end


    test "flags can be enabled and disabled with simple boolean gates", %{flag_name: flag_name} do
      refute ForkWithFlags.enabled?(flag_name)

      ForkWithFlags.enable(flag_name)
      assert ForkWithFlags.enabled?(flag_name)

      ForkWithFlags.disable(flag_name)
      refute ForkWithFlags.enabled?(flag_name)
    end


    test "flags can be enabled for specific actors", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      refute ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)

      ForkWithFlags.enable(flag_name, for_actor: scrooge)
      refute ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)

      ForkWithFlags.enable(flag_name)
      assert ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      assert ForkWithFlags.enabled?(flag_name, for: donald)
    end


    test "flags can be disabled for specific actors", %{scrooge: scrooge, donald: donald, flag_name: flag_name} do
      refute ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)

      ForkWithFlags.enable(flag_name)
      assert ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      assert ForkWithFlags.enabled?(flag_name, for: donald)

      ForkWithFlags.disable(flag_name, for_actor: donald)
      assert ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)

      ForkWithFlags.disable(flag_name)
      refute ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)

      ForkWithFlags.enable(flag_name, for_actor: scrooge)
      refute ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
    end


    test "flags can be enabled for specific groups", %{scrooge: scrooge, donald: donald, mickey: mickey, flag_name: flag_name} do
      refute ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
      refute ForkWithFlags.enabled?(flag_name, for: mickey)

      ForkWithFlags.enable(flag_name, for_group: :ducks)
      refute ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      assert ForkWithFlags.enabled?(flag_name, for: donald)
      refute ForkWithFlags.enabled?(flag_name, for: mickey)

      ForkWithFlags.enable(flag_name)
      assert ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      assert ForkWithFlags.enabled?(flag_name, for: donald)
      assert ForkWithFlags.enabled?(flag_name, for: mickey)
    end


    test "flags can be disabled for specific groups", %{scrooge: scrooge, donald: donald, mickey: mickey, flag_name: flag_name} do
      ForkWithFlags.enable(flag_name)
      assert ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      assert ForkWithFlags.enabled?(flag_name, for: donald)
      assert ForkWithFlags.enabled?(flag_name, for: mickey)

      ForkWithFlags.disable(flag_name, for_group: :ducks)
      assert ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
      assert ForkWithFlags.enabled?(flag_name, for: mickey)

      ForkWithFlags.disable(flag_name)
      refute ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
      refute ForkWithFlags.enabled?(flag_name, for: mickey)
    end


    @tag :flaky
    test "flags can be enabled for a percentage of the time", %{scrooge: scrooge, donald: donald, mickey: mickey, flag_name: flag_name} do
      refute ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
      refute ForkWithFlags.enabled?(flag_name, for: mickey)

      ForkWithFlags.enable(flag_name, for_percentage_of: {:time, 0.999999999})
      assert ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      assert ForkWithFlags.enabled?(flag_name, for: donald)
      assert ForkWithFlags.enabled?(flag_name, for: mickey)
    end

    @tag :flaky
    test "flags can be disabled for a percentage of the time", %{scrooge: scrooge, donald: donald, mickey: mickey, flag_name: flag_name} do
      refute ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
      refute ForkWithFlags.enabled?(flag_name, for: mickey)

      ForkWithFlags.enable(flag_name, for_percentage_of: {:time, 0.999999999})
      assert ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      assert ForkWithFlags.enabled?(flag_name, for: donald)
      assert ForkWithFlags.enabled?(flag_name, for: mickey)

      ForkWithFlags.disable(flag_name, for_percentage_of: {:time, 0.999999999})
      refute ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
      refute ForkWithFlags.enabled?(flag_name, for: mickey)
    end


    # ForkWithFlags.Actor.Percentage.score donald, :turnip
    # 0.7209625244140625
    #
    # ForkWithFlags.Actor.Percentage.score scrooge, :turnip
    # 0.298553466796875
    #
    # ForkWithFlags.Actor.Percentage.score mickey, :turnip
    # 0.3033447265625
    #
    test "flags can be enabled for a percentage of the actors", %{scrooge: scrooge, donald: donald, mickey: mickey} do
      flag_name = :turnip

      refute ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
      refute ForkWithFlags.enabled?(flag_name, for: mickey)

      ForkWithFlags.enable(flag_name, for_percentage_of: {:actors, 0.73}) # enabled for all
      refute ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      assert ForkWithFlags.enabled?(flag_name, for: donald)
      assert ForkWithFlags.enabled?(flag_name, for: mickey)

      ForkWithFlags.enable(flag_name, for_percentage_of: {:actors, 0.299}) # enabled for scrooge
      refute ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
      refute ForkWithFlags.enabled?(flag_name, for: mickey)
    end

    test "flags can be disabled for a percentage of the actors", %{scrooge: scrooge, donald: donald, mickey: mickey} do
      flag_name = :turnip

      refute ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
      refute ForkWithFlags.enabled?(flag_name, for: mickey)

      ForkWithFlags.enable(flag_name, for_percentage_of: {:actors, 0.73}) # enabled for all
      refute ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: scrooge)
      assert ForkWithFlags.enabled?(flag_name, for: donald)
      assert ForkWithFlags.enabled?(flag_name, for: mickey)

      ForkWithFlags.disable(flag_name, for_percentage_of: {:actors, 0.99}) # disabled for all
      refute ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: scrooge)
      refute ForkWithFlags.enabled?(flag_name, for: donald)
      refute ForkWithFlags.enabled?(flag_name, for: mickey)
    end


    test "enabling always returns the tuple {:ok, true} on success", %{flag_name: flag_name} do
      assert {:ok, true} = ForkWithFlags.enable(flag_name)
      assert {:ok, true} = ForkWithFlags.enable(flag_name)
      assert {:ok, true} = ForkWithFlags.enable(flag_name, for_actor: "a string")
      assert {:ok, true} = ForkWithFlags.enable(flag_name, for_group: :group_name)
      assert {:ok, true} = ForkWithFlags.enable(flag_name, for_percentage_of: {:time, 0.5})
      assert {:ok, true} = ForkWithFlags.enable(flag_name, for_percentage_of: {:actors, 0.5})
    end

    test "disabling always returns the tuple {:ok, false} on success", %{flag_name: flag_name} do
      assert {:ok, false} = ForkWithFlags.disable(flag_name)
      assert {:ok, false} = ForkWithFlags.disable(flag_name)
      assert {:ok, false} = ForkWithFlags.disable(flag_name, for_actor: "a string")
      assert {:ok, false} = ForkWithFlags.disable(flag_name, for_group: :group_name)
      assert {:ok, false} = ForkWithFlags.disable(flag_name, for_percentage_of: {:time, 0.5})
      assert {:ok, false} = ForkWithFlags.disable(flag_name, for_percentage_of: {:actors, 0.5})
    end
  end


  describe "clearing flags" do
    setup do
      scrooge = %ForkWithFlags.TestUser{id: 1, email: "scrooge@mcduck.pdp", groups: [:ducks, :billionaires]}
      donald = %ForkWithFlags.TestUser{id: 2, email: "donald@duck.db", groups: [:ducks, :super_heroes]}
      mickey = %ForkWithFlags.TestUser{id: 3, email: "mickey@mouse.tp", groups: [:mice]}
      {:ok, scrooge: scrooge, donald: donald, mickey: mickey, name: unique_atom()}
    end

    test "clearing an enabled global flag will remove its rules and make it disabled", %{name: name} do
      ForkWithFlags.enable(name)
      assert ForkWithFlags.enabled?(name)
      :ok = ForkWithFlags.clear(name)
      refute ForkWithFlags.enabled?(name)
    end

    @tag :flaky
    test "clearing a flag with different gates will remove its rules and make it disabled", %{scrooge: scrooge, donald: donald, mickey: mickey, name: name} do
      ForkWithFlags.disable(name)
      ForkWithFlags.enable(name, for_actor: mickey)
      ForkWithFlags.enable(name, for_group: :ducks)
      ForkWithFlags.enable(name, for_percentage_of: {:time, 0.999999999})

      assert ForkWithFlags.enabled?(name)
      assert ForkWithFlags.enabled?(name, for: scrooge)
      assert ForkWithFlags.enabled?(name, for: donald)
      assert ForkWithFlags.enabled?(name, for: mickey)

      :ok = ForkWithFlags.clear(name)

      refute ForkWithFlags.enabled?(name)
      refute ForkWithFlags.enabled?(name, for: scrooge)
      refute ForkWithFlags.enabled?(name, for: donald)
      refute ForkWithFlags.enabled?(name, for: mickey)
    end
  end


  describe "clearing gates" do
    setup do
      scrooge = %ForkWithFlags.TestUser{id: 1, email: "scrooge@mcduck.pdp", groups: [:ducks, :billionaires]}
      donald = %ForkWithFlags.TestUser{id: 2, email: "donald@duck.db", groups: [:ducks, :super_heroes]}
      mickey = %ForkWithFlags.TestUser{id: 3, email: "mickey@mouse.tp", groups: [:mice]}
      {:ok, scrooge: scrooge, donald: donald, mickey: mickey, name: unique_atom()}
    end

    test "clearing an enabled actor gate will remove its rule", %{donald: donald, mickey: mickey, name: name} do
      ForkWithFlags.disable(name)
      ForkWithFlags.enable(name, for_actor: donald)

      refute ForkWithFlags.enabled?(name)
      assert ForkWithFlags.enabled?(name, for: donald)
      refute ForkWithFlags.enabled?(name, for: mickey)

      :ok = ForkWithFlags.clear(name, for_actor: donald)

      refute ForkWithFlags.enabled?(name)
      refute ForkWithFlags.enabled?(name, for: donald)
      refute ForkWithFlags.enabled?(name, for: mickey)
    end

    test "clearing a disabled actor gate will remove its rule", %{donald: donald, mickey: mickey, name: name} do
      ForkWithFlags.enable(name)
      ForkWithFlags.disable(name, for_actor: donald)

      assert ForkWithFlags.enabled?(name)
      refute ForkWithFlags.enabled?(name, for: donald)
      assert ForkWithFlags.enabled?(name, for: mickey)

      :ok = ForkWithFlags.clear(name, for_actor: donald)

      assert ForkWithFlags.enabled?(name)
      assert ForkWithFlags.enabled?(name, for: donald)
      assert ForkWithFlags.enabled?(name, for: mickey)
    end

    test "clearing an enabled group gate will remove its rule", %{scrooge: scrooge, donald: donald, mickey: mickey, name: name} do
      ForkWithFlags.disable(name)
      ForkWithFlags.enable(name, for_group: :ducks)

      refute ForkWithFlags.enabled?(name)
      assert ForkWithFlags.enabled?(name, for: donald)
      assert ForkWithFlags.enabled?(name, for: scrooge)
      refute ForkWithFlags.enabled?(name, for: mickey)

      :ok = ForkWithFlags.clear(name, for_group: :ducks)

      refute ForkWithFlags.enabled?(name)
      refute ForkWithFlags.enabled?(name, for: donald)
      refute ForkWithFlags.enabled?(name, for: scrooge)
      refute ForkWithFlags.enabled?(name, for: mickey)
    end

    test "clearing a disabled group gate will remove its rule", %{scrooge: scrooge, donald: donald, mickey: mickey, name: name} do
      ForkWithFlags.enable(name)
      ForkWithFlags.disable(name, for_group: :ducks)

      assert ForkWithFlags.enabled?(name)
      refute ForkWithFlags.enabled?(name, for: donald)
      refute ForkWithFlags.enabled?(name, for: scrooge)
      assert ForkWithFlags.enabled?(name, for: mickey)

      :ok = ForkWithFlags.clear(name, for_group: :ducks)

      assert ForkWithFlags.enabled?(name)
      assert ForkWithFlags.enabled?(name, for: donald)
      assert ForkWithFlags.enabled?(name, for: scrooge)
      assert ForkWithFlags.enabled?(name, for: mickey)
    end

    test "clearing a boolean gate will remove its rule and not affect the other gates", %{scrooge: scrooge, donald: donald, mickey: mickey, name: name}  do
      ForkWithFlags.enable(name)
      ForkWithFlags.disable(name, for_group: "ducks")
      ForkWithFlags.enable(name, for_actor: mickey)

      assert ForkWithFlags.enabled?(name)
      refute ForkWithFlags.enabled?(name, for: donald)
      refute ForkWithFlags.enabled?(name, for: scrooge)
      assert ForkWithFlags.enabled?(name, for: mickey)

      :ok = ForkWithFlags.clear(name, boolean: :true)

      refute ForkWithFlags.enabled?(name)
      refute ForkWithFlags.enabled?(name, for: donald)
      refute ForkWithFlags.enabled?(name, for: scrooge)
      assert ForkWithFlags.enabled?(name, for: mickey)
    end

    @tag :flaky
    test "clearing a for_percentage_of_time gate will remove its rule and not affect the other gates", %{scrooge: scrooge, donald: donald, mickey: mickey, name: name}  do
      ForkWithFlags.enable(name, for_percentage_of: {:time, 0.999999999})
      ForkWithFlags.disable(name, for_group: "ducks")
      ForkWithFlags.enable(name, for_actor: mickey)

      assert ForkWithFlags.enabled?(name)
      refute ForkWithFlags.enabled?(name, for: donald)
      refute ForkWithFlags.enabled?(name, for: scrooge)
      assert ForkWithFlags.enabled?(name, for: mickey)

      :ok = ForkWithFlags.clear(name, for_percentage: true)

      refute ForkWithFlags.enabled?(name)
      refute ForkWithFlags.enabled?(name, for: donald)
      refute ForkWithFlags.enabled?(name, for: scrooge)
      assert ForkWithFlags.enabled?(name, for: mickey)
    end

    test "clearing a for_percentage_of_actors gate will remove its rule and not affect the other gates", %{scrooge: scrooge, donald: donald, mickey: mickey}  do
      name = :potato

      ForkWithFlags.enable(name, for_percentage_of: {:actors, 0.90}) # enabled for all
      ForkWithFlags.disable(name, for_group: "billionaires")
      ForkWithFlags.enable(name, for_actor: mickey)

      refute ForkWithFlags.enabled?(name)
      assert ForkWithFlags.enabled?(name, for: donald)
      refute ForkWithFlags.enabled?(name, for: scrooge)
      assert ForkWithFlags.enabled?(name, for: mickey)

      :ok = ForkWithFlags.clear(name, for_percentage: true)

      refute ForkWithFlags.enabled?(name)
      refute ForkWithFlags.enabled?(name, for: donald)
      refute ForkWithFlags.enabled?(name, for: scrooge)
      assert ForkWithFlags.enabled?(name, for: mickey)
    end
  end


  describe "gate interactions" do
    alias ForkWithFlags.TestUser, as: User
    setup do
      harry = %User{id: 1, name: "Harry Potter", groups: [:wizards, :gryffindor, :students]}
      hermione = %User{id: 2, name: "Hermione Granger", groups: [:wizards, :gryffindor, :students]}
      voldemort = %User{id: 3, name: "Tom Riddle", groups: [:wizards, :slytherin, :dark_wizards]}
      draco = %User{id: 4, name: "Draco Malfoy", groups: [:wizards, :slytherin, :students, :dark_wizards]}
      dumbledore = %User{id: 5, name: "Albus Dumbledore", groups: [:wizards, :professors, :headmasters]}
      # = %User{id: 6, name: "", groups: []}

      {:ok, flag_name: unique_atom(), harry: harry, hermione: hermione, voldemort: voldemort, draco: draco, dumbledore: dumbledore}
    end

    @tag :flaky
    test "boolean beats for_percentage_of_time when enabled, but not when disabled", %{flag_name: flag_name, hermione: hermione} do
      ForkWithFlags.enable(flag_name, for_percentage_of: {:time, 0.000000001})
      refute ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: hermione)

      ForkWithFlags.enable(flag_name)
      assert ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: hermione)

      ForkWithFlags.enable(flag_name, for_percentage_of: {:time, 0.999999999})
      assert ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: hermione)

      ForkWithFlags.disable(flag_name)
      assert ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: hermione)
    end

    test "boolean beats for_percentage_of_actors when enabled, but not when disabled", %{hermione: hermione} do
      ForkWithFlags.enable(:pumpkin, for_percentage_of: {:actors, 0.01}) # disabled for hermione
      refute ForkWithFlags.enabled?(:pumpkin)
      refute ForkWithFlags.enabled?(:pumpkin, for: hermione)

      ForkWithFlags.enable(:pumpkin)
      assert ForkWithFlags.enabled?(:pumpkin)
      assert ForkWithFlags.enabled?(:pumpkin, for: hermione)

      ForkWithFlags.enable(:pumpkin, for_percentage_of: {:actors, 0.90}) # enabled for hermione
      assert ForkWithFlags.enabled?(:pumpkin)
      assert ForkWithFlags.enabled?(:pumpkin, for: hermione)

      ForkWithFlags.disable(:pumpkin)
      refute ForkWithFlags.enabled?(:pumpkin)
      assert ForkWithFlags.enabled?(:pumpkin, for: hermione)
    end

    test "group beats boolean, actor beats all", %{harry: harry, hermione: hermione, voldemort: voldemort, draco: draco, dumbledore: dumbledore} do
      flag_name = :bromstick

      refute ForkWithFlags.enabled?(flag_name, for: harry)
      refute ForkWithFlags.enabled?(flag_name, for: hermione)
      refute ForkWithFlags.enabled?(flag_name, for: voldemort)
      refute ForkWithFlags.enabled?(flag_name, for: draco)
      refute ForkWithFlags.enabled?(flag_name, for: dumbledore)

      ForkWithFlags.enable(flag_name, for_percentage_of: {:actors, 0.38}) # enabled for voldemort and draco
      refute ForkWithFlags.enabled?(flag_name, for: harry)
      refute ForkWithFlags.enabled?(flag_name, for: hermione)
      assert ForkWithFlags.enabled?(flag_name, for: voldemort)
      assert ForkWithFlags.enabled?(flag_name, for: draco)
      refute ForkWithFlags.enabled?(flag_name, for: dumbledore)

      ForkWithFlags.enable(flag_name, for_group: :students)
      assert ForkWithFlags.enabled?(flag_name, for: harry)
      assert ForkWithFlags.enabled?(flag_name, for: hermione)
      assert ForkWithFlags.enabled?(flag_name, for: voldemort)
      assert ForkWithFlags.enabled?(flag_name, for: draco)
      refute ForkWithFlags.enabled?(flag_name, for: dumbledore)

      ForkWithFlags.enable(flag_name, for_percentage_of: {:actors, 0.01}) # disabled for all
      assert ForkWithFlags.enabled?(flag_name, for: harry)
      assert ForkWithFlags.enabled?(flag_name, for: hermione)
      refute ForkWithFlags.enabled?(flag_name, for: voldemort)
      assert ForkWithFlags.enabled?(flag_name, for: draco)
      refute ForkWithFlags.enabled?(flag_name, for: dumbledore)

      ForkWithFlags.disable(flag_name, for_group: :gryffindor)
      refute ForkWithFlags.enabled?(flag_name, for: harry)
      refute ForkWithFlags.enabled?(flag_name, for: hermione)
      refute ForkWithFlags.enabled?(flag_name, for: voldemort)
      assert ForkWithFlags.enabled?(flag_name, for: draco)
      refute ForkWithFlags.enabled?(flag_name, for: dumbledore)

      ForkWithFlags.enable(flag_name, for_actor: hermione)
      refute ForkWithFlags.enabled?(flag_name, for: harry)
      assert ForkWithFlags.enabled?(flag_name, for: hermione)
      refute ForkWithFlags.enabled?(flag_name, for: voldemort)
      assert ForkWithFlags.enabled?(flag_name, for: draco)
      refute ForkWithFlags.enabled?(flag_name, for: dumbledore)

      ForkWithFlags.enable(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: harry)
      assert ForkWithFlags.enabled?(flag_name, for: hermione)
      assert ForkWithFlags.enabled?(flag_name, for: voldemort)
      assert ForkWithFlags.enabled?(flag_name, for: draco)
      assert ForkWithFlags.enabled?(flag_name, for: dumbledore)

      ForkWithFlags.disable(flag_name, for_group: :dark_wizards)
      refute ForkWithFlags.enabled?(flag_name, for: harry)
      assert ForkWithFlags.enabled?(flag_name, for: hermione)
      refute ForkWithFlags.enabled?(flag_name, for: voldemort)
      refute ForkWithFlags.enabled?(flag_name, for: draco)
      assert ForkWithFlags.enabled?(flag_name, for: dumbledore)

      ForkWithFlags.disable(flag_name, for_actor: dumbledore)
      refute ForkWithFlags.enabled?(flag_name, for: harry)
      assert ForkWithFlags.enabled?(flag_name, for: hermione)
      refute ForkWithFlags.enabled?(flag_name, for: voldemort)
      refute ForkWithFlags.enabled?(flag_name, for: draco)
      refute ForkWithFlags.enabled?(flag_name, for: dumbledore)

      ForkWithFlags.enable(flag_name, for_actor: voldemort)
      refute ForkWithFlags.enabled?(flag_name, for: harry)
      assert ForkWithFlags.enabled?(flag_name, for: hermione)
      assert ForkWithFlags.enabled?(flag_name, for: voldemort)
      refute ForkWithFlags.enabled?(flag_name, for: draco)
      refute ForkWithFlags.enabled?(flag_name, for: dumbledore)

      ForkWithFlags.enable(flag_name, for_actor: harry)
      assert ForkWithFlags.enabled?(flag_name, for: harry)
      assert ForkWithFlags.enabled?(flag_name, for: hermione)
      assert ForkWithFlags.enabled?(flag_name, for: voldemort)
      refute ForkWithFlags.enabled?(flag_name, for: draco)
      refute ForkWithFlags.enabled?(flag_name, for: dumbledore)
    end


    test "with conflicting group settings, DISABLED groups have the precedence", %{flag_name: flag_name, harry: harry, draco: draco, voldemort: voldemort} do
      ForkWithFlags.disable(flag_name)
      refute ForkWithFlags.enabled?(flag_name)
      refute ForkWithFlags.enabled?(flag_name, for: harry)
      refute ForkWithFlags.enabled?(flag_name, for: draco)
      refute ForkWithFlags.enabled?(flag_name, for: voldemort)

      ForkWithFlags.enable(flag_name, for_group: :students)
      refute ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: harry)
      assert ForkWithFlags.enabled?(flag_name, for: draco)
      refute ForkWithFlags.enabled?(flag_name, for: voldemort)

      ForkWithFlags.disable(flag_name, for_group: :slytherin)
      refute ForkWithFlags.enabled?(flag_name)
      assert ForkWithFlags.enabled?(flag_name, for: harry)
      refute ForkWithFlags.enabled?(flag_name, for: draco)
      refute ForkWithFlags.enabled?(flag_name, for: voldemort)
    end
  end


  describe "looking up a flag after a delay (indirectly test the cache TTL, if present)" do
    alias ForkWithFlags.Config

    test "the flag value is still set even after the TTL of the cache (regardless of the cache being present)" do
      flag_name = unique_atom()

      assert false == ForkWithFlags.enabled?(flag_name)
      {:ok, true} = ForkWithFlags.enable(flag_name)
      assert true == ForkWithFlags.enabled?(flag_name)

      timetravel by: (Config.cache_ttl + 10_000) do
        assert true == ForkWithFlags.enabled?(flag_name)
      end
    end
  end


  describe "all_flags() returns the tuple {:ok, list} with all the flags" do
    alias ForkWithFlags.{Flag, Gate}
    test "with no saved flags it returns an empty list" do
      clear_test_db()
      assert {:ok, []} = ForkWithFlags.all_flags()
    end

    test "with saved flags it returns a list of flags" do
      clear_test_db()

      name1 = unique_atom()
      ForkWithFlags.enable(name1)

      name2 = unique_atom()
      ForkWithFlags.disable(name2)

      name3 = unique_atom()
      actor = %{actor_id: "I'm an actor"}
      ForkWithFlags.enable(name3, for_actor: actor)

      name4 = unique_atom()
      ForkWithFlags.disable(name4, for_percentage_of: {:time, 0.1})

      {:ok, result} = ForkWithFlags.all_flags()
      assert 4 = length(result)

      for flag <- [
        %Flag{name: name1, gates: [Gate.new(:boolean, true)]},
        %Flag{name: name2, gates: [Gate.new(:boolean, false)]},
        %Flag{name: name3, gates: [Gate.new(:actor, actor, true)]},
        %Flag{name: name4, gates: [Gate.new(:percentage_of_time, 0.9)]},
      ] do
        assert flag in result
      end

      ForkWithFlags.clear(name1)

      {:ok, result} = ForkWithFlags.all_flags()
      assert 3 = length(result)

      for flag <- [
        %Flag{name: name2, gates: [Gate.new(:boolean, false)]},
        %Flag{name: name3, gates: [Gate.new(:actor, actor, true)]},
        %Flag{name: name4, gates: [Gate.new(:percentage_of_time, 0.9)]},
      ] do
        assert flag in result
      end

      ForkWithFlags.clear(name4)

      {:ok, result} = ForkWithFlags.all_flags()
      assert 2 = length(result)

      for flag <- [
        %Flag{name: name2, gates: [Gate.new(:boolean, false)]},
        %Flag{name: name3, gates: [Gate.new(:actor, actor, true)]},
      ] do
        assert flag in result
      end
    end
  end


  describe "all_flag_names() returns the tuple {:ok, list}, with the names of all the flags" do
    test "with no saved flags it returns an empty list" do
      clear_test_db()
      assert {:ok, []} = ForkWithFlags.all_flag_names()
    end

    test "with saved flags it returns a list of flag names" do
      clear_test_db()

      name1 = unique_atom()
      ForkWithFlags.enable(name1)

      name2 = unique_atom()
      ForkWithFlags.disable(name2)

      name3 = unique_atom()
      ForkWithFlags.enable(name3, for_actor: %{hello: "I'm an actor"})

      name4 = unique_atom()
      ForkWithFlags.enable(name4, for_percentage_of: {:time, 0.1})

      {:ok, result} = ForkWithFlags.all_flag_names()
      assert 4 = length(result)

      for name <- [name1, name2, name3, name4] do
        assert name in result
      end

      ForkWithFlags.clear(name1)

      {:ok, result} = ForkWithFlags.all_flag_names()
      assert 3 = length(result)

      for name <- [name2, name3, name4] do
        assert name in result
      end

      ForkWithFlags.clear(name4)

      {:ok, result} = ForkWithFlags.all_flag_names()
      assert 2 = length(result)

      for name <- [name2, name3] do
        assert name in result
      end
    end
  end


  describe "get_flag(name) returns a single flag or nil" do
    alias ForkWithFlags.{Flag, Gate}

    setup do
      clear_test_db()
      {:ok, name: unique_atom()}
    end

    test "with the name of a non existing flag, it returns nil", %{name: name} do
      assert nil == ForkWithFlags.get_flag(name)
    end

    test "with the name of an existing flag, it returns the flag", %{name: name} do
      ForkWithFlags.disable(name)
      ForkWithFlags.enable(name, for_group: "foobar")
      ForkWithFlags.disable(name, for_percentage_of: {:time, 0.25})

      expected = %Flag{
        name: name,
        gates: [
          Gate.new(:boolean, false),
          Gate.new(:group, "foobar", true),
          Gate.new(:percentage_of_time, 0.75),
        ]
      }

      assert ^expected = ForkWithFlags.get_flag(name)
    end
  end
end
