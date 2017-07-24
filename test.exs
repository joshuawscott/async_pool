defmodule A do
  def foo(0), do: 1
  def foo(1), do: 1
  def foo(n), do: foo(n-1) + foo(n-2)
end

Task.async_stream(1..1_000_000, fn n ->
  Task.async(fn ->
    x = A.foo(10)
    IO.puts "x: #{n}"
    x
  end)
end, max_concurrency: 12)
|> Stream.run()
