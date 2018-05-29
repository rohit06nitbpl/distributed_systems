defmodule PastryProtocol.Mixfile do
  use Mix.Project

  def project do
    [
      app: :pastry_protocol,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def escript do
    [main_module: PastryProtocol, name: "project3"]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      #{:array, "~> 1.0.1"},
      #{:sorted_set, "~> 1.1.0"},
      #{:red_black_tree, "~> 1.0"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end
end
