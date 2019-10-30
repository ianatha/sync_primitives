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


  test "CountDownLatch executes immediately when at 0" do
    latch = CountDownLatch.start(2)

    CountDownLatch.count_down(latch)
    CountDownLatch.count_down(latch)

    assert CountDownLatch.count(latch) == 0

    assert CountDownLatch.await(latch, 1) == :ok

    CountDownLatch.stop(latch)
  end

  test "CountDownLatch blocks one process until we count down" do
    latch = CountDownLatch.start(2)
    tester = self()

    spawn(fn ->
      CountDownLatch.await(latch)
      send(tester, {:latch_released, :os.system_time()})
    end)

    assert CountDownLatch.count(latch) == 2

    CountDownLatch.count_down(latch)

    latch_released_after = :os.system_time()
    CountDownLatch.count_down(latch)

    receive do
      {:latch_released, at} ->
        assert at > latch_released_after
    end

    assert CountDownLatch.count(latch) == 0

    CountDownLatch.stop(latch)
  end

  test "CountDownLatch await times out" do
    latch = CountDownLatch.start(2)

    before_await = :os.system_time()
    :timeout = CountDownLatch.await(latch, 100)
    after_await = :os.system_time()

    assert after_await - before_await / 1_000_000 > 100
    assert CountDownLatch.count(latch) == 2

    CountDownLatch.count_down(latch)

    assert CountDownLatch.count(latch) == 1
    :timeout = CountDownLatch.await(latch, 100)

    CountDownLatch.stop(latch)
  end

  test "CountDownLatch runs actions when at 0" do
    tester = self()

    latch = CountDownLatch.start(2, fn ->
      send(tester, {:latch_released, :os.system_time()})
    end)

    CountDownLatch.count_down(latch)

    latch_released_after = :os.system_time()

    CountDownLatch.count_down(latch)

    receive do
      {:latch_released, at} ->
        assert at > latch_released_after
    end

    CountDownLatch.stop(latch)
  end
end
