defmodule ForkWithFlags.TimestampsTest do
  use ForkWithFlags.TestCase
  alias ForkWithFlags.Timestamps, as: TS

  test "now() returns a Unix timestamp" do
    assert is_integer(TS.now)

    %DateTime{
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      second: second # I assume the tests are fast enough
    } = DateTime.utc_now

    assert {:ok, %DateTime{
      year: ^year,
      month: ^month,
      day: ^day,
      hour: ^hour,
      minute: ^minute,
      second: ^second
    }} = DateTime.from_unix(TS.now)
  end


  describe "expired?() tells if a timestamp is past its ttl" do
    test "it returns true when the timestamp is expired" do
      one_min_ago = TS.now - 60
      assert TS.expired?(one_min_ago, 10)
      assert TS.expired?(one_min_ago, 59)
    end

    test "it returns false when the timestamp is not expired" do
      one_min_ago = TS.now - 60
      refute TS.expired?(one_min_ago, 61)
      refute TS.expired?(one_min_ago, 3600)
    end
  end
end
