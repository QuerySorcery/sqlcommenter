defmodule Sqlcommenter.MixProject do
  use Mix.Project

  @version "0.2.0-beta.2"
  def project do
    [
      app: :sqlcommenter,
      version: @version,
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
      source_url: "https://github.com/querysorcery/sqlcommenter",
      links: %{
        GitHub: "https://github.com/querysorcery/sqlcommenter",
        Specification: "https://google.github.io/sqlcommenter/"
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:benchee, "~> 1.1", only: :dev}
    ]
  end
end
