defmodule ChatgptWeb.PageController do
  use ChatgptWeb, :controller

  # render normal page
  def home(conn, _params) do
    render(conn, :home)
  end

  # render liveview
  def anotherpage(conn, _params) do
    live_render(conn, ChatgptWeb.IndexLive,
      session: %{
        "rendered_by" => "controller"
      }
    )
  end
end
