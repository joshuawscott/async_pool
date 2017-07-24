defmodule AsyncPool do
  @moduledoc """
  AsyncPool is a worker pool for workloads that require more workers than producers, and for
  situations where batching, like with Task.async_stream/5, is not optimal because the background
  tasks have a highly variable completion time, e.g. web scraping.
  """

  use GenServer

  @type callback :: ((term) -> {:ok, term} | {:error, term})
  @type options :: [callback: callback, max_workers: pos_integer]

  @dwell 5 # ms to wait between retries

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
      task_sup: pid(),
      max_workers: pos_integer(),
      callback: AsyncPool.callback(),
      tasks: Map.t
    }

    defstruct [:task_sup, :max_workers, :callback, :tasks]
  end

  @doc """
  Start an AsyncPool. Passes through to GenServer.start_link
  """
  @spec start_link(options) :: GenServer.on_start
  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  # API

  @doc """
  Main entry point - the `data` is passed to the `perform` function in a background task.
  Will timeout if no workers are available within the timeout.
  """
  @spec add_task(GenServer.server(), term(), timeout()) :: {:ok, reference()}
  def add_task(pid, data, timeout \\ 5000) do
    case GenServer.call(pid, {:add_task, data}, timeout) do
      :retry ->
        :timer.sleep(@dwell)
        add_task(pid, data, timeout)

      ref when is_reference(ref) ->
        {:ok, ref}
    end
  end

  # GenServer

  @doc false
  @spec init(options) :: {:ok, State.t}
  def init(options) do
    {:ok, task_sup} = Task.Supervisor.start_link()
    state = %State{
      callback: Keyword.get(options, :callback),
      max_workers: Keyword.get(options, :max_workers),
      task_sup: task_sup,
      tasks: %{}
    }
    {:ok, state}
  end

  @doc false
  def handle_call({:add_task, data}, {from_pid, _ref}, state) do
    if workers_available?(state) do
      task = Task.Supervisor.async(state.task_sup,
                                   fn -> state.callback.(data) end)
      tasks = Map.put(state.tasks, task.ref, %{task: task, from: from_pid})
      new_state = %{state | tasks: tasks}
      {:reply, task.ref, new_state}
    else
      {:reply, :retry, state}
    end
  end

  # Send the return value back to the calling process
  def handle_info({ref, return_value}, state) when is_reference(ref) do
    {%{task: %Task{}, from: from_pid}, tasks} = Map.pop(state.tasks, ref)
    send(from_pid, {ref, return_value})
    {:noreply, %{state| tasks: tasks}}
  end

  # Handle the exit messages from the tasks.
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state), do: {:noreply, state}

  # Helpers

  defp workers_available?(%State{} = state) do
    map_size(state.tasks) < state.max_workers
  end
end
