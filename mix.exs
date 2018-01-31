defmodule NervesNTP.Mixfile do
  use Mix.Project

  def project do
    [
      app: :nerves_ntp,
      version: "0.2.1"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end
end
