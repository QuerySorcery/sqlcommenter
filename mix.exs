defmodule Sqlcommenter.MixProject do
  use Mix.Project

  def project do
    [
      app: :sqlcommenter,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  defp description do
    """
    Serialize and deserilze sqlcommenter data in sql queries
    """
  end
  defp package do
    [
      name: :sqlcommenter,
      licenses: ["Apache-2.0"],
      source_url: "https://github.com/dkuku/sqlcommenter",
      links: %{
        GitHub: "https://github.com/dkuku/sqlcommenter",
        Specification: "https://google.github.io/sqlcommenter/"
      }
    ]
  end
  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.28", only: :dev, runtime: false}
    ]
  end
end
