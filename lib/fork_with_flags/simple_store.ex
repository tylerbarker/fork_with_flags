defmodule ForkWithFlags.SimpleStore do
  @moduledoc false

  import ForkWithFlags.Config, only: [persistence_adapter: 0]

  @spec lookup(atom) :: {:ok, ForkWithFlags.Flag.t}
  def lookup(flag_name) do
    case persistence_adapter().get(flag_name) do
      {:ok, flag} -> {:ok, flag}
      _ -> raise "Can't load feature flag"
    end
  end

  @spec put(atom, ForkWithFlags.Gate.t) :: {:ok, ForkWithFlags.Flag.t} | {:error, any()}
  def put(flag_name, gate) do
    persistence_adapter().put(flag_name, gate)
  end

  @spec delete(atom, ForkWithFlags.Gate.t) :: {:ok, ForkWithFlags.Flag.t} | {:error, any()}
  def delete(flag_name, gate) do
    persistence_adapter().delete(flag_name, gate)
  end

  @spec delete(atom) :: {:ok, ForkWithFlags.Flag.t} | {:error, any()}
  def delete(flag_name) do
    persistence_adapter().delete(flag_name)
  end

  @spec all_flags() :: {:ok, [ForkWithFlags.Flag.t]} | {:error, any()}
  def all_flags do
    persistence_adapter().all_flags()
  end

  @spec all_flag_names() :: {:ok, [atom]} | {:error, any()}
  def all_flag_names do
    persistence_adapter().all_flag_names()
  end
end
