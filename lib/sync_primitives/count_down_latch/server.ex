defmodule SyncPrimitives.CountDownLatch.Server do
  @moduledoc false
  use GenServer

  require Record

  Record.defrecordp(:state,
    step: :waiting,
    count: nil,
    action: nil,
    q: :queue.new()
  )

  @impl true
  def init(count: count, action: action) do
    {:ok, state(step: :waiting, count: count, action: action)}
  end

  @impl true
  def handle_call(:count, _, s = state(count: count)) do
    {:reply, count, s}
  end

  @impl true
  def handle_call(
        :await,
        _from,
        s = state(step: :waiting, count: 0)
      ) do
    {:reply, :ok, s}
  end

  @impl true
  def handle_call(
        :await,
        from,
        s = state(step: :waiting, q: q)
      ) do
    {:noreply, state(s, q: :queue.in(from, q))}
  end

  @impl true
  def handle_call(
        {:count_down, i},
        _from,
        s = state(step: :waiting, count: count, action: action, q: q)
      ) do
    cond do
      count == i ->
        done(q, action)

        {:reply, :ok, state(s, count: 0, q: :queue.new())}

      count == 0 ->
        {:reply, :error, s}

      true ->
        {:reply, :ok, state(s, count: count - i)}
    end
  end

  defp broadcast(q, message) do
    for from <- :queue.to_list(q) do
      GenServer.reply(from, message)
    end

    :ok
  end

  defp done(q, action) do
    case action do
      nil -> nil
      action -> action.()
    end

    broadcast(q, :ok)

    :ok
  end
end
