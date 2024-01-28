defmodule StatsdMetric.MixProject do
  use Mix.Project

  @version "0.1.0"
  @repo_url "https://github.com/elliotekj/statsd_metric"

  def project do
    [
      app: :statsd_metric,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      docs: docs()
    ]
  end

  def application, do: []

  defp deps, do: [{:ex_doc, "~> 0.31", only: :dev, runtime: false}]

  defp package do
    [
      maintainers: ["Elliot Jackson"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @repo_url}
    ]
  end

  defp description do
    """
    A fast StatsD / DogStatsD metric encoder and single-pass parser.
    """
  end

  defp docs do
    [
      name: "StatsdMetric",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/statsd_metric",
      source_url: @repo_url
    ]
  end
end
