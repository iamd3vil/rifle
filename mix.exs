defmodule Rifle.MixProject do
  use Mix.Project

  def project do
    [
      app: :rifle,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      name: "Rifle",
      source_url: "https://github.com/iamd3vil/rifle",
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: []
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gun, "== 1.0.0-pre.5", only: :dev},
      {:ex_doc, "~> 0.14", only: :dev}
    ]
  end

  defp description do
    "Elixir HTTP Client which supports HTTP 1.1 & HTTP 2 & Websockets. Wrapper over gun (https://github.com/ninenines/gun)"
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      licenses: ["MIT"],
      maintainers: ["Sarat Chandra <me@saratchandra.in>"],
      links: %{
        "Github" => "https://github.com/iamd3vil/rifle",
        "Online Documentation" => "https://hexdocs.pm/rifle"
      }
    ]
  end
end
