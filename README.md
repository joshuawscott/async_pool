# async_pool

AsyncPool is an async worker pool for workloads that are unpredictable, such as scraping websites
from a queue.

## Goals

The ideal use case for async_pool is one where an unpredictable flow of work is being added to a
queue, and the work can take a long time to complete due to waiting on I/O, e.g. website archiving
or requesting data from a slow endpoint. In this case, ideally there are a large pool of workers
that will be mostly idle while they wait on network requests to complete, and the slowest jobs
should not prevent faster ones from completing and freeing up slots in the pool.

* Configurable number of workers to give control over CPU/memory/network impact
* Asyncronous response from the `add_task` API call.

## Example

### With a GenServer
```
defmodule Producer do
  use GenServer

  # Normal init function, but starts up an async_pool and keeps it in the state of the GenServer.
  def init([]) do
    {:ok, async_pool} = AsyncPool.start_link(callback: &process/1, max_workers: 3)
    state = %{async_pool: async_pool}
    {:ok, state}
  end

  def process(data) do
    # Do your work here
    {:ok, data}
  end

  # Just provides a way to start a fake work producer. In a real application, you would probably
  # have some sort of a recursive function here.
  def handle_cast(:produce, state) do
    # get some data
    AsyncPool.add_task(state.async_pool, data)
    {:noreply, state}
  end

  # The return value of the callback function (process/1 in this example) is sent to the calling
  # process as {ref, return_value}. This is a plain message, so it comes to the handle_info/2
  # callback in a GenServer. Alternatively you can do a recieve to get the message. By default, a
  # GenServer has a handle_info implementation that just logs when messages come to this endpoint.
  def handle_info({ref, return_value}, state) when is_reference(ref) do
    # do something with the return value here.
    {:noreply, state}
  end
end
```

### Without a GenServer
```
defmodule Producer do
  def start do
    {:ok, async_pool} = AsyncPool.start_link(callback: &process/1, max_workers: 3)

    # Start a main loop
    produce(async_pool)
  end

  def produce(async_pool) do
    # Do something to get some data here
    data = get_data()

    # Send to the async_pool
    AsyncPool.add_task(async_pool, data)

    # Check if we have any pending responses in the mailbox
    receive do
      {ref, return_value} when is_reference(ref) ->
        # Do something with the return value here
      after 0 ->
        :ok
    end
  end

  def process(data) do
    # Do your work here

    # The return value is sent as a message back to this process.
    return_value
  end
end
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `async_pool` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:async_pool, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/async_pool](https://hexdocs.pm/async_pool).
