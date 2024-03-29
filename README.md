# Statsd Metric

**A fast StatsD / DogStatsD metric encoder and single-pass parser.**

`StatsdMetric` supports all standard StatsD metric types:

* Counter
* Gauge
* Histogram
* Timer
* Set
* Meter

It also supports DogStatsD sample rates and tags.

## Installation

The package can be installed by adding `statsd_metric` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:statsd_metric, "~> 0.1"}
  ]
end
```

## Usage ([documentation](https://hexdocs.pm/statsd_metric))

#### Encoding Example

Encoding supports IO list and string return types.

``` elixir
iex> StatsdMetric.encode("name.spaced", 1.0, :counter)
["name.spaced", 58, "1.0", 124, "c"]

iex> StatsdMetric.encode_to_string("name.spaced", 1.0, :counter)
"name.spaced:1.0|c"
```

#### Parsing Example

``` elixir
iex> StatsdMetric.decode!("name.spaced:1.0|c|@0.1|#foo:bar")
%StatsdMetric{
  key: "name.spaced",
  value: 1.0,
  type: :counter,
  sample_rate: 0.1,
  tags: %{"foo" => "bar"}
}
```

## License

`StatsdMetric` is released under the [`Apache License
2.0`](https://github.com/elliotekj/statsd_metric/blob/main/LICENSE).

## About

This package was written by [Elliot Jackson](https://elliotekj.com).

- Blog: [https://elliotekj.com](https://elliotekj.com)
- Email: elliot@elliotekj.com
