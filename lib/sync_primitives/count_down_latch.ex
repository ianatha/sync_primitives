defmodule SyncPrimitives.CountDownLatch do
  @moduledoc """
  A CountDownLatch expects `count` calls to `count_down/2` before calls to
  `await/2` can continue.

  A CountDownLatch is initialized with a `count`.

  `await/2` blocks until the current count reaches 0 due to invocations of the
  `count_down/2` method, after which all blocked processes are unblocked.

  Any subsequent invocations of `await/2` return immediately. This is a
  one-shot phenomenon -- the count cannot be reset. If you need a version that
  resets the count, consider using a `SyncPrimitives.CyclicBarrier`.

  ## Example

      iex> latch = SyncPrimitives.CountDownLatch.start(2, fn -> IO.puts("latch done") end)
      {SyncPrimitives.CountDownLatch, #PID<0.227.0>}
      iex> spawn_link(fn ->
      ...>  IO.puts("before wait")
      ...>  SyncPrimitives.CountDownLatch.await(latch)
      ...>  IO.puts("after wait")
      ...> end)
      before wait
      #PID<0.233.0>
      iex> # nothing happens for a while
      nil
      iex> SyncPrimitives.CountDownLatch.count_down(latch)
      :ok
      iex> SyncPrimitives.CountDownLatch.count_down(latch)
      latch done
      after wait
      :ok
      iex> SyncPrimitives.CountDownLatch.stop(latch)
      :ok
  """

  require Record

  Record.defrecordp(:latch, __MODULE__, pid: nil)
  @type latch :: record(:latch, pid: pid)

  @server_module Module.concat(__MODULE__, Server)

  @spec start(pos_integer, nil | (() -> any)) :: latch
  def start(count, action \\ nil)
      when is_integer(count) and count > 0 and (action === nil or is_function(action, 0)) do
    {:ok, server_pid} = GenServer.start_link(@server_module, count: count, action: action)
    latch(pid: server_pid)
  end

  @spec stop(latch) :: :ok
  def stop(latch(pid: pid)) do
    GenServer.stop(pid)
  end

  @spec alive?(latch) :: boolean
  def alive?(latch(pid: pid)) do
    Process.alive?(pid)
  end

  @spec count(latch) :: false | integer
  def count(latch(pid: pid)) do
    GenServer.call(pid, :count)
  end

  @spec count_down(latch, pos_integer) :: :ok
  def count_down(latch(pid: pid), i \\ 1) when is_integer(i) and i > 0 do
    GenServer.call(pid, {:count_down, i})
  end

  @spec await(latch, :infinity | integer) :: :ok | :timeout
  def await(latch(pid: pid), timeout \\ :infinity)
      when timeout === :infinity or is_integer(timeout) do
    case call(pid, :await, timeout) do
      :ok ->
        :ok

      :timeout ->
        :timeout
    end
  end

  defp call(pid, request, timeout) do
    try do
      GenServer.call(pid, request, timeout)
    catch
      :exit, {:timeout, _} ->
        :timeout
    end
  end
end
