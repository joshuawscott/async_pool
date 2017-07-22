# AsyncPool

AsyncPool is a worker pool for workloads that require more workers than producers, and for
situations where batching, like with Task.async_stream/5, is not optimal because the background
tasks have a highly variable completion time, e.g. web scraping.

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

