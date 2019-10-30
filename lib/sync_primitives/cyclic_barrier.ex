defmodule SyncPrimitives.CyclicBarrier do
  @moduledoc """
  A CyclicBarrier expects a predefined number of `parties` to `await/2`
  before all calls to `await/2` can continue.

  Parties _arrive_ at the _barrier_ by calling `await/2`.

  When all `parties` have _arrived_, all calls to `await/2`
  unblock, and parties may proceed.

  Thereafter, the barrier resets (which is what makes it cyclic).

  Although this fully describes the happy path, documentation for time outs,
  participating parties that exit, and other sad paths is currently lacking.

  ## Example

      iex> barrier = SyncPrimitives.CyclicBarrier.start(2, fn -> IO.puts("barrier action") end)
      {SyncPrimitives.CyclicBarrier, #PID<0.149.0>}
      iex> spawn_link(fn ->
      ...>  IO.puts("process 1, before wait")
      ...>  SyncPrimitives.CyclicBarrier.await(barrier)
      ...>  IO.puts("process 1, after wait")
      ...> end)
      process 1, before wait
      #PID<0.155.0>
      iex> spawn_link(fn ->
      ...>  IO.puts("process 2, before wait")
      ...>  SyncPrimitives.CyclicBarrier.await(barrier)
      ...>  IO.puts("process 2, after wait")
      ...> end)
      process 2, before wait
      #PID<0.161.0>
      barrier action
      process 1, after wait
      process 2, after wait
      iex> SyncPrimitives.CyclicBarrier.stop(barrier)
  """

  require Record

  Record.defrecordp(:barrier, __MODULE__, pid: nil)
  @type barrier :: record(:barrier, pid: pid)

  @server_module Module.concat(__MODULE__, Server)

  @doc """
  Starts a new CyclicBarrier that expects `parties` processes to call `await/1`
  or `await/2` before it releases. Calls to `await/1` block until all expected
  parties have called `await/1`. Thereafter, the barrier resets (which is what
  makes it cyclic).
  """
  @spec start(pos_integer, nil | (() -> any)) :: barrier
  def start(parties, action \\ nil)
      when is_integer(parties) and parties > 0 and (action === nil or is_function(action, 0)) do
    {:ok, server_pid} = GenServer.start_link(@server_module, parties: parties, action: action)
    barrier(pid: server_pid)
  end

  @spec stop(barrier) :: :ok
  def stop(_barrier = barrier(pid: pid)) do
    GenServer.stop(pid)
  end

  @spec alive?(barrier) :: boolean
  def alive?(_barrier = barrier(pid: pid)) do
    Process.alive?(pid)
  end

  @spec broken?(barrier) :: boolean
  @doc """
  Returns `true`, if any of the parties waiting for the barrier timed out or,
  exited since construction or the last reset, `false` otherwise.
  """
  def broken?(barrier(pid: pid)) do
    case call(pid, :status) do
      :waiting ->
        false

      :broken ->
        true
    end
  end

  @spec number_waiting(barrier) :: false | integer
  @doc """
  Returns the number of parties currently waiting for the barrier.
  """
  def number_waiting(barrier(pid: pid)) do
    GenServer.call(pid, :number_waiting)
  end

  @spec parties(barrier) :: false | integer
  @doc """
  Returns the number of parties required to trip this barrier.
  """
  def parties(barrier(pid: pid)) do
    GenServer.call(pid, :parties)
  end

  @spec reset(barrier) :: boolean
  @doc """
  Resets the barrier to its initial state. If any parties are currently waiting
  at the barrier, the `await/1` or `await/2` calls will return `:broken`.
  """
  def reset(barrier(pid: pid)) do
    case call(pid, :reset) do
      :reset ->
        true

      :broken ->
        true

      _ ->
        false
    end
  end

  @spec await(barrier, :infinity | integer) :: :fulfilled | :broken
  def await(barrier(pid: pid), timeout \\ :infinity)
      when timeout === :infinity or is_integer(timeout) do
    case call(pid, :await, timeout) do
      :fulfilled ->
        :fulfilled

      :broken ->
        :broken

      :timeout ->
        :broken
    end
  end

  defp call(pid, request, timeout \\ :infinity) do
    try do
      GenServer.call(pid, request, timeout)
    catch
      :exit, {:timeout, _} ->
        GenServer.cast(pid, :attendant_timedout)
        :timeout
    end
  end
end
