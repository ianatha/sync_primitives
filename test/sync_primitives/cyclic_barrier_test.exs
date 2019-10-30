defmodule SyncPrimitives.CyclicBarrierTest do
  use ExUnit.Case

  @moduletag timeout: 2000

  alias SyncPrimitives.CyclicBarrier

  def barrier_action_fn(tester) do
    barrier_start = :os.system_time()

    fn ->
      barrier_end = :os.system_time()
      send(tester, {:barrier, barrier_start, :undef, :undef, barrier_end})
    end
  end

  def attendant_fn(tester, barrier, index, with_timeout \\ nil, and_wait_thereafter \\ nil) do
    fn ->
      before_time = :os.system_time()
      processes_already_waiting = CyclicBarrier.number_waiting(barrier)

      # each attendant "arrives" at the barrier here
      barrier_fulfilled = if with_timeout == nil do
        CyclicBarrier.await(barrier)
      else
        CyclicBarrier.await(barrier, with_timeout)
      end

      after_time = :os.system_time()

      send(tester, {index, before_time, processes_already_waiting, barrier_fulfilled, after_time})

      if and_wait_thereafter != nil do
        :timer.sleep(and_wait_thereafter)
      end
    end
  end

  def receive_n(n) do
    1..n
    |> Enum.map(fn _ ->
      receive do
        msg -> msg
      end
    end)
  end

  def assert_attendant_messages_correctly_timed(messages, parties) do
    messages =
      messages
      |> Enum.sort_by(&elem(&1, 0))

    assert length(messages) == parties + 1,
           "there should be #{parties + 1} messages received, one for each attendant, and one for the barrier"

    {^parties, last_attendant_started, _, _, _} = messages |> Enum.take(-2) |> hd
    {:barrier, _barrier_started, _, _, barrier_ended} = messages |> Enum.take(-1) |> hd

    messages
    |> Enum.each(fn {_index, _before_time, _processes_already_waiting, _barrier_fulfilled,
                     after_time} ->
      assert after_time > last_attendant_started,
             "all attendants must have passed the barrier after the last attendant arrived at the barrier"

      assert barrier_ended <= after_time,
             "all attendants must have passed the barrier after the barrier was lowered"
    end)
  end

  def start_attendants(
        barrier,
        parties,
        with_timeout \\ nil,
        and_wait_thereafter \\ nil,
        time_between_attendants_arriving \\ 10
      ) do
    # launch `parties` attendants
    1..parties
    |> Enum.each(fn index ->
      spawn_link(attendant_fn(self(), barrier, index, with_timeout, and_wait_thereafter))

      :timer.sleep(time_between_attendants_arriving)
    end)
  end

  test "cyclic barrier passes after all 10 attendants arrive without timeout" do
    parties = 10

    barrier = CyclicBarrier.start(parties, barrier_action_fn(self()))
    assert CyclicBarrier.parties(barrier) == parties
    assert not CyclicBarrier.broken?(barrier)
    CyclicBarrier.reset(barrier)
    refute CyclicBarrier.broken?(barrier)

    CyclicBarrier.stop(barrier)
  end

  test "cyclic barrier passes after all 10 attendants arrive with timeout" do
    parties = 10
    timeout = 100

    barrier = CyclicBarrier.start(parties, barrier_action_fn(self()))
    assert CyclicBarrier.parties(barrier) == parties
    assert not CyclicBarrier.broken?(barrier)

    start_attendants(barrier, parties, timeout)
    messages = receive_n(parties + 1)
    assert_attendant_messages_correctly_timed(messages, parties)

    CyclicBarrier.stop(barrier)
  end

  test "cyclic barrier timeout" do
    parties = 2

    barrier = CyclicBarrier.start(parties)
    assert CyclicBarrier.parties(barrier) == parties
    assert not CyclicBarrier.broken?(barrier)
    timeout = 100

    # launch 1 attendant -- this barrier will never be fulfilled
    start_attendants(barrier, 1, timeout)
    {1, attendant_start, _procs_before, barrier_fulfilled, attendant_end} = receive_n(1) |> hd

    assert barrier_fulfilled == :broken, "barrier must have timed out"

    assert attendant_end - attendant_start > timeout * 1_000_000,
           "barrier must have waited at least #{timeout} before timing out"

    assert CyclicBarrier.alive?(barrier)
    assert CyclicBarrier.broken?(barrier)

    :ok = CyclicBarrier.stop(barrier)
  end

  test "cyclic barrier resets automatically when successful" do
    parties = 10

    barrier = CyclicBarrier.start(parties, barrier_action_fn(self()))

    assert CyclicBarrier.parties(barrier) == parties
    assert not CyclicBarrier.broken?(barrier)

    # use the barrier once
    start_attendants(barrier, parties)
    messages = receive_n(parties + 1)
    assert_attendant_messages_correctly_timed(messages, parties)

    assert not CyclicBarrier.broken?(barrier)

    # use the barrier twice
    start_attendants(barrier, parties)
    messages = receive_n(parties + 1)
    assert_attendant_messages_correctly_timed(messages, parties)

    assert not CyclicBarrier.broken?(barrier)

    CyclicBarrier.stop(barrier)
  end

  test "cyclic barrier resets and works correctly after timeout" do
    parties = 2

    barrier = CyclicBarrier.start(parties, barrier_action_fn(self()))
    assert CyclicBarrier.parties(barrier) == parties
    assert not CyclicBarrier.broken?(barrier)
    timeout = 100

    # use the barrier once
    # launch 1 attendant -- this barrier will never be fulfilled
    start_attendants(barrier, 1, timeout)
    {1, attendant_start, _procs_before, barrier_fulfilled, attendant_end} = receive_n(1) |> hd

    assert barrier_fulfilled == :broken, "barrier must have timed out"

    assert attendant_end - attendant_start > timeout * 1_000_000,
           "barrier must have waited at least #{timeout} before timing out"

    assert CyclicBarrier.broken?(barrier)

    CyclicBarrier.reset(barrier)

    assert not CyclicBarrier.broken?(barrier)

    # use the barrier twice
    start_attendants(barrier, parties)
    messages = receive_n(parties + 1)
    assert_attendant_messages_correctly_timed(messages, parties)

    CyclicBarrier.stop(barrier)
  end

  test "reset unblocks participants waiting at the barrier" do
    parties = 3

    barrier = CyclicBarrier.start(parties)
    assert CyclicBarrier.parties(barrier) == parties
    assert not CyclicBarrier.broken?(barrier)

    # use the barrier once
    # launch 1 attendant -- this barrier will never be fulfilled
    start_attendants(barrier, parties - 1)

    CyclicBarrier.reset(barrier)

    messages = receive_n(parties - 1)

    messages
    |> Enum.each(fn
      {_index, _attendant_start, _procs_before, barrier_fulfilled, _attendant_end} ->
        assert barrier_fulfilled == :broken, "barrier must have timed out"
    end)

    refute CyclicBarrier.broken?(barrier), "barrier not must be broken"

    CyclicBarrier.stop(barrier)
  end

  test "can't await on broken barrier" do
    parties = 2

    barrier = CyclicBarrier.start(parties, barrier_action_fn(self()))
    timeout = 100

    # use the barrier once
    # launch 1 attendant -- this barrier will never be fulfilled
    start_attendants(barrier, 1, timeout)
    {1, _attendant_start, _procs_before, barrier_fulfilled, _attendant_end} = receive_n(1) |> hd

    assert barrier_fulfilled == :broken, "barrier must have timed out"

    assert CyclicBarrier.broken?(barrier)

    assert CyclicBarrier.await(barrier) == :broken

    CyclicBarrier.stop(barrier)
  end

  test "cyclic barrier timeout when process doesn't exit after barrier returns :broken" do
    parties = 2

    barrier = CyclicBarrier.start(parties)
    assert CyclicBarrier.parties(barrier) == parties
    assert not CyclicBarrier.broken?(barrier)
    timeout = 100

    # launch 1 attendant -- this barrier will never be fulfilled
    start_attendants(barrier, 1, timeout, 10000)
    {1, attendant_start, _procs_before, barrier_fulfilled, attendant_end} = receive_n(1) |> hd

    assert barrier_fulfilled == :broken, "barrier must have timed out"

    assert attendant_end - attendant_start > timeout * 1_000_000,
           "barrier must have waited at least #{timeout} before timing out"

    assert CyclicBarrier.alive?(barrier)
    assert CyclicBarrier.broken?(barrier)

    :ok = CyclicBarrier.stop(barrier)
  end
end
