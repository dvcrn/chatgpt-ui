defmodule ChatgptWeb.MessageListComponent do
  alias ChatgptWeb.MessageComponent
  alias ChatgptWeb.Message
  use ChatgptWeb, :live_component

  attr :messages, :list, required: true

  def render(assigns) do
    ~H"""
    <div class="my-4 relative h-full w-full transition-width flex flex-col items-stretch flex-1">
      <%= for message <- @messages |> Enum.filter(& &1.content != "") do %>
        <.live_component
          module={MessageComponent}
          id={message.id}
          message={message.content}
          sender={message.sender}
        />
      <% end %>
    </div>
    """
  end
end
