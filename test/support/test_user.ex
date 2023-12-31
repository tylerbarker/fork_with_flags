defmodule ForkWithFlags.TestUser do
  # A Test user
  defstruct [:id, :email, :name, groups: []]
end

defimpl ForkWithFlags.Actor, for: ForkWithFlags.TestUser do
  def id(%{id: id}) do
    "user:#{id}"
  end
end


defimpl ForkWithFlags.Group, for: ForkWithFlags.TestUser do
  def in?(%{email: email}, "admin") do
    Regex.match?(~r/@wayne.com$/, email)
  end

  def in?(user, :admin) do
    __MODULE__.in?(user, "admin")
  end

  # Matches binaries or atoms.
  #
  def in?(%{groups: groups}, group) when is_list(groups) do
    group_s = to_string(group)
    Enum.any? groups, fn(g) -> to_string(g) == group_s end
  end
end
