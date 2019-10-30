defmodule SyncPrimitives.CyclicBarrier.Server do
  @moduledoc false
  use GenServer

  require Record

  Record.defrecordp(:state,
    step: :waiting,
    waiting: 0,
    parties: nil,
    action: nil,
    q: :queue.new()
  )

  @impl true
  def init(parties: parties, action: action) do
    {:ok, state(step: :waiting, parties: parties, action: action)}
  end

  @impl true
  def handle_call(:parties, _, s = state(parties: parties)) do
    {:reply, parties, s}
  end

  @impl true
  def handle_call(:status, _, s = state(step: step)) do
    {:reply, step, s}
  end

  @impl true
  def handle_call(:number_waiting, _, s = state(waiting: waiting)) do
    {:reply, waiting, s}
  end

  @impl true
  def handle_call(
        :await,
        from,
        s = state(step: :waiting, parties: parties, action: action, waiting: waiting, q: q)
      ) do
    {pid, genserver_ref} = from
    monitor_ref = Process.monitor(pid)
    new_queue = :queue.in({pid, genserver_ref, monitor_ref}, q)

    new_state =
      if parties == waiting + 1 do
        done(:fulfilled, action, new_queue)

        state(s,
          step: :waiting,
          waiting: 0,
          q: :queue.new()
        )
      else
        state(s,
          step: :waiting,
          waiting: waiting + 1,
          q: new_queue
        )
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:await, _from, s = state(step: :broken)) do
    {:reply, :broken, s}
  end

  @impl true
  def handle_call(:reset, _from, s = state(step: :broken)) do
    {:reply, :ok, state(s, step: :waiting, waiting: 0, q: :queue.new())}
  end

  @impl true
  def handle_call(:reset, _from, s = state(step: :waiting, waiting: 0)) do
    {:reply, :ok, state(s, step: :waiting, waiting: 0, q: :queue.new())}
  end

  @impl true
  def handle_call(:reset, _from, s = state(step: :waiting, q: q)) do
    done(:broken, nil, q)

    {:reply, :ok,
     state(s,
       step: :waiting,
       waiting: 0,
       q: :queue.new()
     )}
  end

  @impl true
  def handle_cast(:attendant_timedout, s = state(step: :waiting, q: q)) do
    done(:broken, nil, q)

    {:noreply, state(s, step: :broken, waiting: 0, q: :queue.new())}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _exit_reason}, s = state(step: :waiting, q: q)) do
    done(:broken, nil, q)

    {:noreply, state(s, step: :broken, waiting: 0, q: :queue.new())}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _exit_reason}, s = state(step: :broken)) do
    {:noreply, s}
  end

  defp broadcast(q, message) do
    for {pid, genserver_ref, monitor_ref} <- :queue.to_list(q) do
      Process.demonitor(monitor_ref)
      GenServer.reply({pid, genserver_ref}, message)
    end

    :ok
  end

  defp done(state, action, q) do
    case action do
      nil -> nil
      action -> action.()
    end

    broadcast(q, state)

    :ok
  end
end
