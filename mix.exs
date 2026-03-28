defmodule NornsSdk.MixProject do
  use Mix.Project

  def project do
    [
      app: :norns_sdk,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Elixir SDK for Norns — durable agent runtime on BEAM",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:slipstream, "~> 1.0"},
      {:jason, "~> 1.4"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/amackera/norns-sdk-elixir",
        "Norns Runtime" => "https://github.com/amackera/norns"
      }
    ]
  end
end
