defmodule ForkWithFlags.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    ForkWithFlags.Supervisor.start_link(nil)
  end
end
