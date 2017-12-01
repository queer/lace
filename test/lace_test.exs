defmodule LaceTest do
  use ExUnit.Case
  doctest Lace

  test "greets the world" do
    assert Lace.hello() == :world
  end
end
