# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :chatgpt,
  title: "Elixir ChatGPT",
  # or gpt-3.5-turbo
  default_model: :"gpt-4",
  models: [
    %{
      id: :"claude-3-opus-20240229",
      provider: :anthropic,
      truncate_tokens: 100_000,
      name: "Claude 3 Opus"
    },
    %{
      id: :"gpt-4",
      provider: :openai,
      truncate_tokens: 8000,
      name: "GPT4"
    },
    %{
      id: :"gpt-3.5-turbo",
      provider: :openai,
      truncate_tokens: 4000,
      name: "GPT3.5 Turbo"
    },
    %{
      id: :"gpt-3.5-turbo-16k",
      provider: :openai,
      truncate_tokens: 15000,
      name: "GPT3.5 Turbo 16k"
    },
    %{
      id: :"gpt-4-32k",
      provider: :openai,
      truncate_tokens: 30000,
      name: "GPT4 32k (EXPENSIVE!)"
    }
  ],
  enable_google_oauth: true,
  restrict_email_domains: true,
  allowed_email_domains: ["google.com"]

# Configures the endpoint
config :chatgpt, ChatgptWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: ChatgptWeb.ErrorHTML, json: ChatgptWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Chatgpt.PubSub,
  live_view: [signing_salt: "U3AoOojJ"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.41",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.2.4",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
