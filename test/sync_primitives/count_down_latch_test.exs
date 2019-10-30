defmodule SyncPrimitives.CountDownLatchTest do
  use ExUnit.Case

  @moduletag timeout: 2000

  alias SyncPrimitives.CountDownLatch

  test "CountDownLatch counts down" do
    latch = CountDownLatch.start(2)

    assert CountDownLatch.alive?(latch)

    assert CountDownLatch.count(latch) == 2

    CountDownLatch.count_down(latch)
    assert CountDownLatch.count(latch) == 1

    CountDownLatch.count_down(latch)
    assert CountDownLatch.count(latch) == 0

    assert CountDownLatch.count_down(latch) == :error

    CountDownLatch.stop(latch)
  end
end
