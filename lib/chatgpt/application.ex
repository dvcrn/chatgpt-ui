defmodule Chatgpt.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      ChatgptWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Chatgpt.PubSub},
      # Start Finch
      {Finch, name: Chatgpt.Finch},
      # Start the Endpoint (http/https)
      ChatgptWeb.Endpoint
      # Start a worker by calling: Chatgpt.Worker.start_link(arg)
      # {Chatgpt.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Chatgpt.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ChatgptWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
