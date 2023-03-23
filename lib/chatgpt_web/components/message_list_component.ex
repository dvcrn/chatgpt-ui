defmodule ChatgptWeb.MessageListComponent do
  alias ChatgptWeb.MessageComponent
  alias ChatgptWeb.Message
  use ChatgptWeb, :live_component

  attr :messages, :list, required: true

  def render(assigns) do
    ~H"""
    <div class="my-4 relative h-full w-full transition-width flex flex-col overflow-hidden items-stretch flex-1">
      <%= for message <- @messages do %>
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
