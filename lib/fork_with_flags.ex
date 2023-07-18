defmodule ForkWithFlags do
  @moduledoc """
  ForkWithFlags, the Elixir feature flag library.

  This module provides the public interface to the library and its API is
  made of three simple methods to enable, disable and query feature flags.

  In their simplest form, flags can be toggled on and off globally.

  More advanced rules or "gates" are available, and they can be set and queried
  for any term that implements these protocols:

  * The `ForkWithFlags.Actor` protocol can be
  implemented for types and structs that should have specific rules. For
  example, in web applications it's common to use a `%User{}` struct or
  equivalent as an actor, or perhaps the current country of the request.

  * The `ForkWithFlags.Group` protocol can be
  implemented for types and structs that should belong to groups for which
  one wants to enable and disable some flags. For example, one could implement
  the protocol for a `%User{}` struct to identify administrators.


  See the [Usage](/fork_with_flags/readme.html#usage) notes for a more detailed
  explanation.
  """

  alias ForkWithFlags.{Config, Flag, Gate}

  @store ForkWithFlags.Config.store_module_determined_at_compile_time()

  @type options :: Keyword.t


  @doc """
  Checks if a flag is enabled.

  It can be invoked with just the flag name, as an atom,
  to check the general status of a flag (i.e. the boolean gate).

  ## Options

  * `:for` - used to provide a term for which the flag could
  have a specific value. The passed term should implement the
  `Actor` or `Group` protocol, or both.

  ## Examples

  This example relies on the [reference implementation](https://github.com/tylerbarker/fork_with_flags/blob/master/test/support/test_user.ex)
  used in the tests.

      iex> alias ForkWithFlags.TestUser, as: User
      iex> harry = %User{id: 1, name: "Harry Potter", groups: ["wizards", "gryffindor"]}
      iex> ForkWithFlags.disable(:elder_wand)
      iex> ForkWithFlags.enable(:elder_wand, for_actor: harry)
      iex> ForkWithFlags.enabled?(:elder_wand)
      false
      iex> ForkWithFlags.enabled?(:elder_wand, for: harry)
      true
      iex> voldemort = %User{id: 7, name: "Tom Riddle", groups: ["wizards", "slytherin"]}
      iex> ForkWithFlags.enabled?(:elder_wand, for: voldemort)
      false
      iex> filch = %User{id: 88, name: "Argus Filch", groups: ["staff"]}
      iex> ForkWithFlags.enable(:magic_wands, for_group: "wizards")
      iex> ForkWithFlags.enabled?(:magic_wands, for: harry)
      true
      iex> ForkWithFlags.enabled?(:magic_wands, for: voldemort)
      true
      iex> ForkWithFlags.enabled?(:magic_wands, for: filch)
      false

  """
  @spec enabled?(atom, options) :: boolean
  def enabled?(flag_name, options \\ [])

  def enabled?(flag_name, []) when is_atom(flag_name) do
    {:ok, flag} = @store.lookup(flag_name)
    Flag.enabled?(flag)
  end

  def enabled?(flag_name, [for: nil]) do
    enabled?(flag_name)
  end

  def enabled?(flag_name, [for: item]) when is_atom(flag_name) do
    {:ok, flag} = @store.lookup(flag_name)
    Flag.enabled?(flag, for: item)
  end


  @doc """
  Enables a feature flag.

  ## Options

  * `:for_actor` - used to enable the flag for a specific term only.
  The value can be any term that implements the `Actor` protocol.
  * `:for_group` - used to enable the flag for a specific group only.
  The value should be a binary or an atom (It's internally converted
  to a binary and it's stored and retrieved as a binary. Atoms are
  supported for retro-compatibility with versions <= 0.9)
  * `:for_percentage_of` - used to enable the flag for a percentage
  of time or actors, expressed as `{:time, float}` or `{:actors, float}`,
  where float is in the range `0.0 < x < 1.0`.

  ## Examples

  ### Enable globally

      iex> ForkWithFlags.enabled?(:super_shrink_ray)
      false
      iex> ForkWithFlags.enable(:super_shrink_ray)
      {:ok, true}
      iex> ForkWithFlags.enabled?(:super_shrink_ray)
      true

  ### Enable for an actor

      iex> ForkWithFlags.disable(:warp_drive)
      {:ok, false}
      iex> ForkWithFlags.enable(:warp_drive, for_actor: "Scotty")
      {:ok, true}
      iex> ForkWithFlags.enabled?(:warp_drive)
      false
      iex> ForkWithFlags.enabled?(:warp_drive, for: "Scotty")
      true

  ### Enable for a group

  This example relies on the [reference implementation](https://github.com/tylerbarker/fork_with_flags/blob/master/test/support/test_user.ex)
  used in the tests.

      iex> alias ForkWithFlags.TestUser, as: User
      iex> marty = %User{name: "Marty McFly", groups: ["students", "time_travelers"]}
      iex> doc = %User{name: "Emmet Brown", groups: ["scientists", "time_travelers"]}
      iex> buford = %User{name: "Buford Tannen", groups: ["gunmen", "bandits"]}
      iex> ForkWithFlags.enable(:delorean, for_group: "time_travelers")
      {:ok, true}
      iex> ForkWithFlags.enabled?(:delorean)
      false
      iex> ForkWithFlags.enabled?(:delorean, for: buford)
      false
      iex> ForkWithFlags.enabled?(:delorean, for: marty)
      true
      iex> ForkWithFlags.enabled?(:delorean, for: doc)
      true


  ### Enable for a percentage of the time

      iex> ForkWithFlags.disable(:random_glitch)
      iex> ForkWithFlags.enable(:random_glitch, for_percentage_of: {:time, 0.999999999})
      iex> ForkWithFlags.enabled?(:random_glitch)
      true
      iex> ForkWithFlags.enable(:random_glitch, for_percentage_of: {:time, 0.000000001})
      iex> ForkWithFlags.enabled?(:random_glitch)
      false

  ### Enable for a percentage of the actors

  This example is based on the fact that the actor score for the actor-flag pair
  `marty + :new_ui` is lower than 50%, and for the `buford + :new_ui` is higher.

      iex> ForkWithFlags.disable(:new_ui)
      iex> ForkWithFlags.enable(:new_ui, for_percentage_of: {:actors, 0.5})
      iex> ForkWithFlags.enabled?(:new_ui)
      false
      iex> alias ForkWithFlags.TestUser, as: User
      iex> marty = %User{id: 42, name: "Marty McFly"}
      iex> buford = %User{id: 2, name: "Buford Tannen"}
      iex> ForkWithFlags.enabled?(:new_ui, for: marty)
      true
      iex> ForkWithFlags.enabled?(:new_ui, for: buford)
      false

  """
  @spec enable(atom, options) :: {:ok, true} | {:error, any}
  def enable(flag_name, options \\ [])

  def enable(flag_name, []) when is_atom(flag_name) do
    gate = Gate.new(:boolean, true)
    case @store.put(flag_name, gate) do
      {:ok, flag} -> verify(flag)
      error -> error
    end
  end

  def enable(flag_name, [for_actor: nil]) do
    enable(flag_name)
  end

  def enable(flag_name, [for_actor: actor]) when is_atom(flag_name) do
    gate = Gate.new(:actor, actor, true)
    case @store.put(flag_name, gate) do
      {:ok, flag} -> verify(flag, for: actor)
      error -> error
    end
  end


  def enable(flag_name, [for_group: nil]) do
    enable(flag_name)
  end

  def enable(flag_name, [for_group: group_name]) when is_atom(flag_name) do
    gate = Gate.new(:group, group_name, true)
    case @store.put(flag_name, gate) do
      {:ok, _flag} -> {:ok, true}
      error -> error
    end
  end


  def enable(flag_name, [for_percentage_of: {:time, ratio}]) when is_atom(flag_name) do
    gate = Gate.new(:percentage_of_time, ratio)
    case @store.put(flag_name, gate) do
      {:ok, _flag} -> {:ok, true}
      error -> error
    end
  end

  def enable(flag_name, [for_percentage_of: {:actors, ratio}]) when is_atom(flag_name) do
    gate = Gate.new(:percentage_of_actors, ratio)
    case @store.put(flag_name, gate) do
      {:ok, _flag} -> {:ok, true}
      error -> error
    end
  end


  @doc """
  Disables a feature flag.

  ## Options

  * `:for_actor` - used to disable the flag for a specific term only.
  The value can be any term that implements the `Actor` protocol.
  * `:for_group` - used to disable the flag for a specific group only.
   The value should be a binary or an atom (It's internally converted
  to a binary and it's stored and retrieved as a binary. Atoms are
  supported for retro-compatibility with versions <= 0.9)
  * `:for_percentage_of` - used to disable the flag for a percentage
  of time or actors, expressed as `{:time, float}` or `{:actors, float}`,
  where float is in the range `0.0 < x < 1.0`.

  ## Examples

  ### Disable globally

      iex> ForkWithFlags.enable(:random_koala_gifs)
      iex> ForkWithFlags.enabled?(:random_koala_gifs)
      true
      iex> ForkWithFlags.disable(:random_koala_gifs)
      {:ok, false}
      iex> ForkWithFlags.enabled?(:random_koala_gifs)
      false


  ## Disable for an actor

      iex> ForkWithFlags.enable(:spider_sense)
      {:ok, true}
      iex> villain = %{name: "Venom"}
      iex> ForkWithFlags.disable(:spider_sense, for_actor: villain)
      {:ok, false}
      iex> ForkWithFlags.enabled?(:spider_sense)
      true
      iex> ForkWithFlags.enabled?(:spider_sense, for: villain)
      false

  ### Disable for a group

  This example relies on the [reference implementation](https://github.com/tylerbarker/fork_with_flags/blob/master/test/support/test_user.ex)
  used in the tests.

      iex> alias ForkWithFlags.TestUser, as: User
      iex> harry = %User{name: "Harry Potter", groups: ["wizards", "gryffindor"]}
      iex> dudley = %User{name: "Dudley Dursley", groups: ["muggles"]}
      iex> ForkWithFlags.enable(:hogwarts)
      {:ok, true}
      iex> ForkWithFlags.disable(:hogwarts, for_group: "muggles")
      {:ok, false}
      iex> ForkWithFlags.enabled?(:hogwarts)
      true
      iex> ForkWithFlags.enabled?(:hogwarts, for: harry)
      true
      iex> ForkWithFlags.enabled?(:hogwarts, for: dudley)
      false

  ### Disable for a percentage of the time

      iex> ForkWithFlags.clear(:random_glitch)
      :ok
      iex> ForkWithFlags.disable(:random_glitch, for_percentage_of: {:time, 0.999999999})
      {:ok, false}
      iex> ForkWithFlags.enabled?(:random_glitch)
      false
      iex> ForkWithFlags.disable(:random_glitch, for_percentage_of: {:time, 0.000000001})
      {:ok, false}
      iex> ForkWithFlags.enabled?(:random_glitch)
      true

  ### Disable for a percentage of the actors

      iex> ForkWithFlags.disable(:new_ui, for_percentage_of: {:actors, 0.3})
      {:ok, false}

  """
  @spec disable(atom, options) :: {:ok, false} | {:error, any}
  def disable(flag_name, options \\ [])

  def disable(flag_name, []) when is_atom(flag_name) do
    gate = Gate.new(:boolean, false)
    case @store.put(flag_name, gate) do
      {:ok, flag} -> verify(flag)
      error -> error
    end
  end

  def disable(flag_name, [for_actor: nil]) do
    disable(flag_name)
  end

  def disable(flag_name, [for_actor: actor]) when is_atom(flag_name) do
    gate = Gate.new(:actor, actor, false)
    case @store.put(flag_name, gate) do
      {:ok, flag} -> verify(flag, for: actor)
      error -> error
    end
  end

  def disable(flag_name, [for_group: nil]) do
    disable(flag_name)
  end

  def disable(flag_name, [for_group: group_name]) when is_atom(flag_name) do
    gate = Gate.new(:group, group_name, false)
    case @store.put(flag_name, gate) do
      {:ok, _flag} -> {:ok, false}
      error -> error
    end
  end


  def disable(flag_name, [for_percentage_of: {type, ratio}])
  when is_atom(flag_name) and is_float(ratio) do
    inverted_ratio = 1.0 - ratio
    case enable(flag_name, [for_percentage_of: {type, inverted_ratio}]) do
      {:ok, true} -> {:ok, false}
      error -> error
    end
  end


  @doc """
  Clears the data of a feature flag.

  Clears the data for an entire feature flag or for a specific
  Actor or Group gate. Clearing a boolean gate is not supported
  because a missing boolean gate is equivalent to a disabled boolean
  gate.

  Sometimes enabling or disabling a gate is not what you want, and you
  need to remove that gate's rules instead. For example, if you don't need
  anymore to explicitly enable or disable a flag for an actor, and the
  default state should be used instead, you'll want to clear the gate.

  It's also possible to clear the entire flag, by not passing any option.

  ## Options

  * `for_actor: an_actor` - used to clear the flag for a specific term only.
  The value can be any term that implements the `Actor` protocol.
  * `for_group: a_group_name` - used to clear the flag for a specific group only.
   The value should be a binary or an atom (It's internally converted
  to a binary and it's stored and retrieved as a binary. Atoms are
  supported for retro-compatibility with versions <= 0.9)
  * `boolean: true` - used to clear the boolean gate.
  * `for_percentage: true` - used to clear any percentage gate.

  ## Examples

      iex> alias ForkWithFlags.TestUser, as: User
      iex> harry = %User{id: 1, name: "Harry Potter", groups: ["wizards", "gryffindor"]}
      iex> hagrid = %User{id: 2, name: "Rubeus Hagrid", groups: ["wizards", "gamekeeper"]}
      iex> dudley = %User{id: 3, name: "Dudley Dursley", groups: ["muggles"]}
      iex> ForkWithFlags.disable(:wands)
      iex> ForkWithFlags.enable(:wands, for_group: "wizards")
      iex> ForkWithFlags.disable(:wands, for_actor: hagrid)
      iex>
      iex> ForkWithFlags.enabled?(:wands)
      false
      iex> ForkWithFlags.enabled?(:wands, for: harry)
      true
      iex> ForkWithFlags.enabled?(:wands, for: hagrid)
      false
      iex> ForkWithFlags.enabled?(:wands, for: dudley)
      false
      iex>
      iex> ForkWithFlags.clear(:wands, for_actor: hagrid)
      :ok
      iex> ForkWithFlags.enabled?(:wands, for: hagrid)
      true
      iex>
      iex> ForkWithFlags.clear(:wands)
      :ok
      iex> ForkWithFlags.enabled?(:wands)
      false
      iex> ForkWithFlags.enabled?(:wands, for: harry)
      false
      iex> ForkWithFlags.enabled?(:wands, for: hagrid)
      false
      iex> ForkWithFlags.enabled?(:wands, for: dudley)
      false

  """
  @spec clear(atom, options) :: :ok | {:error, any}
  def clear(flag_name, options \\ [])

  def clear(flag_name, []) when is_atom(flag_name) do
    case @store.delete(flag_name) do
      {:ok, _flag} -> :ok
      error -> error
    end
  end

  def clear(flag_name, [boolean: true]) do
    gate = Gate.new(:boolean, false) # we only care about the gate id
    _clear_gate(flag_name, gate)
  end

  def clear(flag_name, [for_actor: nil]) do
    clear(flag_name)
  end

  def clear(flag_name, [for_actor: actor]) when is_atom(flag_name) do
    gate = Gate.new(:actor, actor, false) # we only care about the gate id
    _clear_gate(flag_name, gate)
  end

  def clear(flag_name, [for_group: nil]) do
    clear(flag_name)
  end

  def clear(flag_name, [for_group: group_name]) when is_atom(flag_name) do
    gate = Gate.new(:group, group_name, false) # we only care about the gate id
    _clear_gate(flag_name, gate)
  end

  def clear(flag_name, [for_percentage: true]) do
    gate = Gate.new(:percentage_of_time, 0.5) # we only care about the gate id
    _clear_gate(flag_name, gate)
  end

  defp _clear_gate(flag_name, gate) do
    case @store.delete(flag_name, gate) do
      {:ok, _flag} -> :ok
      error -> error
    end
  end


  @doc """
  Returns a list of all flag names currently configured, as atoms.

  This can be useful for debugging or for display purposes,
  but it's not meant to be used at runtime. Undefined flags,
  for example, will be considered disabled.
  """
  @spec all_flag_names() :: {:ok, [atom]} | {:error, any}
  def all_flag_names do
    Config.persistence_adapter().all_flag_names()
  end

  @doc """
  Returns a list of all the flags currently configured, as data structures.

  This function is provided for debugging and to build more complex
  functionality (e.g. it's used in the web GUI), but it is not meant to be
  used at runtime to check if a flag is enabled.

  To query the value of a flag, please use the `enabled?2` function instead.
  """
  @spec all_flags() :: {:ok, [ForkWithFlags.Flag.t]} | {:error, any}
  def all_flags do
    Config.persistence_adapter().all_flags()
  end


  @doc """
  Returns a `ForkWithFlags.Flag` struct for the given name, or `nil` if
  no flag is found.

  Useful for debugging.
  """
  @spec get_flag(atom) :: ForkWithFlags.Flag.t | nil | {:error, any}
  def get_flag(name) do
    case all_flag_names() do
      {:ok, names} ->
        if name in names do
          case Config.persistence_adapter().get(name) do
            {:ok, flag} -> flag
            error -> error
          end
        else
          nil
        end
      error -> error
    end
  end


  defp verify(flag) do
    {:ok, Flag.enabled?(flag)}
  end
  defp verify(flag, [for: data]) do
    {:ok, Flag.enabled?(flag, for: data)}
  end

  # Used in some tests and to debug.
  #
  # Apparently calling `Config.store_module_determined_at_compile_time` even
  # just once in a test causes all sorts of weird test failures everywhere.
  #
  @doc false
  def compiled_store, do: @store
end
