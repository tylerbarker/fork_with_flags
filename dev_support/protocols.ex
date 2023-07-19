defimpl ForkWithFlags.Actor, for: Map do
  def id(%{actor_id: actor_id}) do
    "map:#{actor_id}"
  end

  def id(map) do
    map
    |> inspect()
    |> (&:crypto.hash(:md5, &1)).()
    |> Base.encode16
    |> (&"map:#{&1}").()
  end
end


defimpl ForkWithFlags.Actor, for: BitString do
  def id(str) do
    "string:#{str}"
  end
end

defimpl ForkWithFlags.Group, for: BitString do
  def in?(str, group_name) do
    String.contains?(str, to_string(group_name))
  end
end


defimpl ForkWithFlags.Group, for: Map do
  def in?(%{group: group_name}, group_name), do: true
  def in?(_, _), do: false
end
