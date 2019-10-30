defmodule SyncPrimitives.MixProject do
  use Mix.Project

  @name :sync_primitives
  @version "0.1.0"
  @maintainers ["Ian Atha <ian@atha.io>"]
  @github "https://github.com/ianatha/#{@name}"
  @source_url @github
  @homepage_url @github

  @description """
  Synchronization primitives for Elixir
  """

  def project do
    [
      app: @name,
      version: @version,
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      package: package(),
      description: @description,
      source_url: @source_url,
      homepage_url: @homepage_url,
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.detail": :test,
        "coveralls.json": :test,
        "coveralls.post": :test,
        "coveralls.travis": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.12", only: [:test]},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      name: @name,
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "LICENSE.md"
      ],
      maintainers: @maintainers,
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => @github
      }
    ]
  end
end
