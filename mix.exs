defmodule NervesNTP.Mixfile do
  use Mix.Project

  def project do
    [
      app: :nerves_ntp,
      version: "0.1.0"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end
end
