defmodule SyncPrimitivesTest do
  use ExUnit.Case
  doctest SyncPrimitives

  test "greets the world" do
    assert SyncPrimitives.hello() == :world
  end
end
