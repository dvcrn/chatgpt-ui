defmodule ChatgptWeb.Router do
  use ChatgptWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {ChatgptWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_view, html: ChatgptWeb.PageHTML
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ChatgptWeb do
    pipe_through :browser

    get "/", PageController, :chat
    get "/chat", PageController, :chat
    get "/scenario/:scenario_id", PageController, :scenario

    get "/auth/google/callback", PageController, :oauth_callback
  end

  # Other scopes may use custom stacks.
  # scope "/api", ChatgptWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:chatgpt, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ChatgptWeb.Telemetry
    end
  end
end
