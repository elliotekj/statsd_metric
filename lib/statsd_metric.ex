defmodule StatsdMetric do
  @moduledoc """
  A fast StatsD / DogStatsD metric encoder and single-pass parser.

  `StatsdMetric` supports all standard StatsD metric types:

  * Counter
  * Gauge
  * Histogram
  * Timer
  * Set
  * Meter

  It also supports DogStatsD sample rates and tags.

  ## Encoding Example

  Encoding supports IO list and string return types.

      iex> StatsdMetric.encode("name.spaced", 1.0, :counter)
      ["name.spaced", 58, "1.0", 124, "c"]

      iex> StatsdMetric.encode_to_string("name.spaced", 1.0, :counter)
      "name.spaced:1.0|c"

  ## Parsing Example

      iex> StatsdMetric.decode!("name.spaced:1.0|c|@0.1|#foo:bar")
      %StatsdMetric{
        key: "name.spaced",
        value: 1.0,
        type: :counter,
        sample_rate: 0.1,
        tags: %{"foo" => "bar"}
      }
  """

  defstruct [:key, :value, :type, :sample_rate, :tags]

  @type t :: %__MODULE__{
          key: String.t(),
          value: float(),
          type: atom(),
          sample_rate: float() | nil,
          tags: map() | nil
        }

  @metrics %{
    counter: "c",
    gauge: "g",
    histogram: "h",
    timer: "ms",
    set: "s",
    meter: "m"
  }

  @nb_chars ~c"+-0123456789.eE"

  @doc """
  Encodes a `%StatsdMetric{}` into a StatsD metric IO list.

      iex> StatsdMetric.encode("name.spaced", 1.0, :counter)
      ["name.spaced", 58, "1.0", 124, "c"]
  """
  @spec encode(binary(), integer() | float(), atom(), keyword()) :: iolist()
  def encode(key, val, type, opts \\ [])

  def encode(key, val, type, opts) when not is_binary(val) do
    encode(key, to_string(val), type, opts)
  end

  def encode(key, val, type, opts) do
    [key, ?:, val, ?|, metric_type(type)]
    |> set_option(:sample_rate, opts[:sample_rate])
    |> set_option(:tags, opts[:tags])
  end

  @doc """
  Encodes a `%StatsdMetric{}` into a StatsD metric string.

      iex> StatsdMetric.encode_to_string("name.spaced", 1.0, :counter)
      "name.spaced:1.0|c"
  """
  @spec encode_to_string(binary(), integer() | float(), atom(), keyword()) :: binary()
  def encode_to_string(key, val, type, opts \\ []) do
    encode(key, val, type, opts)
    |> IO.iodata_to_binary()
  end

  @doc """
  Parses a StatsD metric into a `%StatsdMetric{}`.

      iex> StatsdMetric.decode("name.spaced:1.0|c|@0.1|#foo:bar")
      {:ok, %StatsdMetric{
        key: "name.spaced",
        value: 1.0,
        type: :counter,
        sample_rate: 0.1,
        tags: %{"foo" => "bar"}
      }}
  """
  @spec decode(binary()) :: {:ok, %__MODULE__{}} | {:error, atom()}
  def decode(metric) when is_binary(metric) do
    case eval_key(metric) do
      {:error, error} ->
        {:error, error}

      data ->
        code = {:%{}, [], data}
        {result, _binding} = Code.eval_quoted(code)
        {:ok, struct(__MODULE__, result)}
    end
  end

  @doc """
  Parses a StatsD metric into a `%StatsdMetric{}`.

      iex> StatsdMetric.decode!("name.spaced:1.0|c|@0.1|#foo:bar")
      %StatsdMetric{
        key: "name.spaced",
        value: 1.0,
        type: :counter,
        sample_rate: 0.1,
        tags: %{"foo" => "bar"}
      }

  If the metric is invalid, it raises one of:

  - `StatsdMetric.EmptyError`
  - `StatsdMetric.NoKeyError`
  - `StatsdMetric.NoValueError`
  - `StatsdMetric.NoTypeError`
  """
  @spec decode!(binary()) :: %__MODULE__{}
  def decode!(metric) when is_binary(metric) do
    case decode(metric) do
      {:ok, stat} -> stat
      {:error, :empty} -> raise StatsdMetric.EmptyError
      {:error, :no_key} -> raise StatsdMetric.NoKeyError
      {:error, :no_value} -> raise StatsdMetric.NoValueError
      {:error, :bad_value} -> raise StatsdMetric.BadValueError
      {:error, :no_type} -> raise StatsdMetric.NoTypeError
    end
  end

  for {name, type} <- @metrics do
    defp metric_type(unquote(name)), do: unquote(type)
  end

  defp set_option(metric, _, nil), do: metric

  defp set_option(metric, :sample_rate, sample_rate) do
    [metric | ["|@", :erlang.float_to_binary(sample_rate, [:compact, decimals: 2])]]
  end

  defp set_option(metric, :tags, []), do: metric

  defp set_option(metric, :tags, tags) do
    tags =
      Enum.map(tags, fn
        {k, v} when is_atom(v) -> "#{k}:#{Atom.to_string(v)}"
        {k, v} -> "#{k}:#{v}"
        t when is_binary(t) -> t
      end)

    [metric | ["|#", Enum.join(tags, ",")]]
  end

  defp eval_key(data, key_buffer \\ <<>>, metric_buffer \\ []) do
    case data do
      <<>> ->
        {:error, :empty}

      <<?:, _rest::binary>> when key_buffer == <<>> ->
        {:error, :no_key}

      <<?:, rest::binary>> ->
        eval_value(rest, [{:key, key_buffer} | metric_buffer])

      <<?|, _rest::binary>> ->
        {:error, :no_value}

      <<byte, rest::binary>> ->
        eval_key(rest, key_buffer <> <<byte>>)
    end
  end

  defp eval_value(data, val_buffer \\ <<>>, metric_buffer) do
    case data do
      <<>> ->
        {:error, :no_type}

      <<?|, _rest::binary>> when val_buffer == <<>> ->
        {:error, :no_value}

      <<?|, rest::binary>> ->
        eval_type(rest, [{:value, to_float(val_buffer)} | metric_buffer])

      <<byte, rest::binary>> when byte in @nb_chars ->
        eval_value(rest, val_buffer <> <<byte>>, metric_buffer)

      _ ->
        {:error, :bad_value}
    end
  end

  defp eval_type(<<>>, _metric_buffer), do: {:error, :no_type}

  for {name, type} <- @metrics do
    defp eval_type(<<unquote(type), rest::binary>>, metric_buffer) do
      maybe_eval_sample_rate(rest, [{:type, unquote(name)} | metric_buffer])
    end
  end

  defp maybe_eval_sample_rate(data, metric_buffer) do
    case data do
      <<?|, rest::binary>> -> maybe_eval_sample_rate(rest, metric_buffer)
      <<?@, rest::binary>> -> eval_sample_rate(rest, metric_buffer)
      data -> eval_tags(data, metric_buffer)
    end
  end

  defp eval_sample_rate(data, sample_rate_buffer \\ <<>>, metric_buffer) do
    case data do
      "" ->
        [{:sample_rate, to_float(sample_rate_buffer)} | metric_buffer]

      <<?|, rest::binary>> ->
        metric_buffer = [{:sample_rate, to_float(sample_rate_buffer)} | metric_buffer]
        eval_tags(rest, metric_buffer)

      <<byte, rest::binary>> ->
        eval_sample_rate(rest, sample_rate_buffer <> <<byte>>, metric_buffer)
    end
  end

  defp eval_tags(data, metric_buffer) do
    case data do
      <<?#, rest::binary>> ->
        eval_tag_key(rest, metric_buffer)

      _ ->
        metric_buffer
    end
  end

  defp eval_tag_key(data, tags_buffer \\ [], key \\ <<>>, metric_buffer) do
    case data do
      "" ->
        [{:tags, {:%{}, [], tags_buffer}} | metric_buffer]

      <<?:, rest::binary>> ->
        {value, rest} = eval_tag_value(rest)
        eval_tag_key(rest, [{key, value} | tags_buffer], metric_buffer)

      <<byte, rest::binary>> ->
        eval_tag_key(rest, tags_buffer, key <> <<byte>>, metric_buffer)
    end
  end

  defp eval_tag_value(data, value \\ <<>>) do
    case data do
      "" ->
        {value, ""}

      <<?,, rest::binary>> ->
        {value, rest}

      <<byte, rest::binary>> ->
        eval_tag_value(rest, value <> <<byte>>)
    end
  end

  defp to_float(str) do
    {float, _} = Float.parse(str)
    float
  end
end
