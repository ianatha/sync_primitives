defmodule SyncPrimitives.CountDownLatch do
  @moduledoc false
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
