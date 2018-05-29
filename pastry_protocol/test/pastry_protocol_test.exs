defmodule PastryProtocolTest do
  use ExUnit.Case
  doctest PastryProtocol

  test "greets the world" do
    assert PastryProtocol.hello() == :world
  end
end
