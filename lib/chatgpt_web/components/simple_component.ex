defmodule ChatgptWeb.SimpleComponent do
  use ChatgptWeb, :live_component

  alias Phoenix.LiveView.JS

  attr :id, :string, required: true

  def mount(socket) do
    {:ok,
     socket
     |> assign(count: 0)}
  end

  def handle_event("click", _args, socket) do
    {:noreply, assign(socket, count: socket.assigns.count + 1)}
  end

  def render(assigns) do
    ~H"""
    <div class="border p-4 mt-4 mb-4">
      <p>ID passed: <%= assigns.id %></p>
      <button
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        phx-click="click"
        phx-target={@myself}
      >
        Clicked <%= assigns.count %> times
      </button>
    </div>
    """
  end
end
