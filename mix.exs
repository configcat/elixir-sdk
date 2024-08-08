defmodule ConfigCat.MixProject do
  use Mix.Project

  @source_url "https://github.com/configcat/elixir-sdk"

  def project do
    [
      app: :configcat,
      name: "ConfigCat",
      source_url: @source_url,
      homepage_url: "https://configcat.com/",
      version: "4.0.2",
      elixir: "~> 1.12",
      description: description(),
      package: package(),
      elixirc_options: elixirc_options(Mix.env()),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        list_unused_filters: true,
        plt_local_path: "priv/plts/dialyzer.plt"
      ],
      docs: [
        assets: "assets",
        extras: ["CONTRIBUTING.md", "README.md"],
        formatters: ["html"],
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
      extra_applications: [:logger],
      mod: {ConfigCat.Application, []}
    ]
  end

  defp elixirc_options(:dev) do
    [
      all_warnings: true,
      ignore_module_conflict: true,
      warnings_as_errors: false
    ]
  end

  defp elixirc_options(:test) do
    [
      all_warnings: true,
      warnings_as_error: false
    ]
  end

  defp elixirc_options(_) do
    [
      all_warnings: true,
      warnings_as_errors: true
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:elixir_uuid, "~> 1.2"},
      {:ex_doc, "~> 0.31.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18.0", only: :test},
      {:httpoison, "~> 1.7 or ~> 2.0"},
      {:jason, "~> 1.2"},
      {:mix_test_interactive, "~> 1.2", only: :dev, runtime: false},
      {:mox, "~> 1.1", only: :test},
      {:styler, "~> 0.11", only: [:dev, :test], runtime: false},
      {:typed_struct, "~> 0.3.0"},
      {:tz, "~> 0.26.5", only: :test}
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
