defmodule ConfigCat.MixProject do
  use Mix.Project

  @source_url "https://github.com/configcat/elixir-sdk"

  def project do
    [
      app: :configcat,
      name: "ConfigCat",
      source_url: @source_url,
      homepage_url: "https://configcat.com/",
      version: "1.0.2",
      elixir: "~> 1.10",
      description: description(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        list_unused_filters: true,
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      docs: [
        assets: "assets",
        extras: ["README.md"],
        logo: "assets/logo.png",
        main: "readme"
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.travis": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:elixir_uuid, "~> 1.2"},
      {:httpoison, "~> 1.7"},
      {:jason, "~> 1.2"},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:mox, "~> 1.0", only: :test}
    ]
  end

  defp package do
    [licenses: ["MIT"], links: %{"GitHub" => @source_url}]
  end

  defp description do
    """
    ConfigCat SDK for Elixir.

    Feature Flags created by developers for developers with ❤️. ConfigCat lets you manage feature flags across frontend, backend, mobile, and desktop apps without (re)deploying code. % rollouts, user targeting, segmentation. Feature toggle SDKs for all main languages.
    """
  end
end
