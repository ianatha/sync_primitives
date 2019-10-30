# sync_primitives for Elixir

[![Apache License](https://img.shields.io/hexpm/l/sync_primitives)](LICENSE.md)
[![Hex.pm](https://img.shields.io/hexpm/v/sync_primitives)](https://hex.pm/packages/sync_primitives)
[![Documentation](https://img.shields.io/badge/hexdocs-latest-blue.svg)](https://hexdocs.pm/sync_primitives/index.html)
[![Build Status](https://travis-ci.org/ianatha/sync_primitives.svg?branch=master)](https://travis-ci.org/ianatha/sync_primitives)
[![Coverage Status](https://coveralls.io/repos/github/ianatha/sync_primitives/badge.svg?branch=master)](https://coveralls.io/github/ianatha/sync_primitives?branch=master)

Synchronization Primitives for Elixir, such as `CyclicBarrier` and `CountDownLatch`.

These primitives allow you to synchronize multiple Elixir processes using
higher-level abstractions than messages. I have found them  are very useful in
testing agent-based and mutli-process Elixir apps.

## Installation

`sync_primitives` is available on [Hex](https://hex.pm/). Add `sync_primitives` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:sync_primitives, "~> 0.1.0"}]
end
```

Documentation can be found at [https://hexdocs.pm/sync_primitives](https://hexdocs.pm/sync_primitives).

## CyclicBarrier Usage

1. Start a `CyclicBarrier`
    ```elixir
    barrier = SyncPrimitives.CyclicBarrier.start(2, fn -> IO.puts("barrier action") end)
    ```

2. Start the processes you wish to synchronize through a CyclicBarrier.

    1. The first process:
        ```elixir
        spawn_link(fn ->
          IO.puts("process 1, before wait")
          SyncPrimitives.CyclicBarrier.await(barrier)
          IO.puts("process 1, after wait")
        end)
        ```


    2. Wait for a little bit to see that `process 1` won't reach the "after wait" message.


    3. Start the second process:
        ```elixir
        spawn_link(fn ->
          IO.puts("process 2, before wait")
          SyncPrimitives.CyclicBarrier.await(barrier)
          IO.puts("process 2, after wait")
        end)
        ```

3. All of above will output:
    ```
    process 1, before wait
    process 2, before wait
    barrier action
    process 1, after wait
    process 2, after wait
    ```
