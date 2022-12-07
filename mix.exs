defmodule WebCrawler.MixProject do
  use Mix.Project

  def project do
    [
      app: :web_crawler,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {WebCrawler, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.8"},
      {:floki, "~> 0.31.0"},
      {:libgraph, "~> 0.7"},
      {:xml_builder, "~> 2.1"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.6"}
    ]
  end
end
