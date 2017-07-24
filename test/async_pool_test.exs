defmodule AsyncPoolTest do
  use ExUnit.Case
  doctest AsyncPool

  test "AsyncPool spawns up to the specified number of workers" do
    sleeper = fn x ->
      :timer.sleep 100
      {:ok, x}
    end

    {:ok, pool} = AsyncPool.start_link(callback: sleeper, max_workers: 4)

    assert Process.alive? pool

    {time, results} = :timer.tc(fn ->
      Enum.map(1..5, fn n -> AsyncPool.add_task(pool, n) end)
    end)

    [{:ok, ref1}, {:ok, ref2}, {:ok, ref3}, {:ok, ref4}, {:ok, ref5}] = results

    # Get the results back as info calls:
    receive do
      {^ref1, {:ok, result}} -> assert 1 == result
    end
    receive do
      {^ref2, {:ok, result}} -> assert 2 == result
    end
    receive do
      {^ref3, {:ok, result}} -> assert 3 == result
    end
    receive do
      {^ref4, {:ok, result}} -> assert 4 == result
    end
    receive do
      {^ref5, {:ok, result}} -> assert 5 == result
    end

    # It should take at least 100ms, but not more than 110ms
    assert time >= 100_000
    assert time < 110_000
  end

  defmodule Producer do
    use GenServer
    def init([]) do
      {:ok, async_pool} = AsyncPool.start_link(callback: &process/1, max_workers: 10)
      state = %{
        results: MapSet.new,
        async_pool: async_pool
      }
      {:ok, state}
    end

    def process(n) do
      :timer.sleep 10
      n
    end

    def handle_call(:size, _from, state) do
      {:reply, MapSet.size(state.results), state}
    end

    def handle_cast(:start, state) do
      Enum.each(1..100, fn n -> AsyncPool.add_task(state.async_pool, n) end)
      {:noreply, state}
    end

    def handle_info({_ref, retval}, state) do
      state = %{state | results: MapSet.put(state.results, retval)}
      {:noreply, state}
    end
  end

  test "a GenServer sends work and gets responses" do
    {:ok, producer} = GenServer.start_link(Producer, [])
    GenServer.cast(producer, :start)
    # Let the background tasks finish
    Enum.drop_while(1..10, fn _ ->
      :timer.sleep 1
      MapSet.size(:sys.get_state(producer).results) < 100
    end)
    assert 100 == MapSet.size(:sys.get_state(producer).results)
    results = :sys.get_state(producer).results
    Enum.each(1..100, fn n ->
      assert MapSet.member?(results, n)
    end)
  end
end
