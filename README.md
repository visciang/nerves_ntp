# NervesNtp

Synchronizes time using busybox `ntpd` command. Primary use is for [Nerves](http://nerves-project.org) embedded devices.

## Installation

Add `nerves_ntp` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:nerves_ntp,  git: "https://github.com/visciang/nerves_ntp.git", tag: "xxx"]
end
```

## Usage

If your application needs a mandatory sync at startup, add at the beginning of your application module:

```elixir
defmodule MyApplication do
  use Application

  def start(_type, _args) do
    # blocks till a successful sync completes
    NervesNTP.sync(true)

    # ...

    Supervisor.start_link(children, opts)    
  end
end
```
