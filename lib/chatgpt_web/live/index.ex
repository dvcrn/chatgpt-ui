defmodule ChatgptWeb.IndexLive do
  alias ChatgptWeb.Message
  alias ChatgptWeb.LoadingIndicatorComponent
  alias ChatgptWeb.AlertComponent
  use ChatgptWeb, :live_view

  @type state :: %{messages: [Message.t()], loading: boolean()}

  @spec dummy_messages() :: [Message.t()]
  defp dummy_messages,
    do: [
      %Message{content: "Hi there! Ask me something :)", sender: :assistant, id: 0}
    ]

  @spec initial_state() :: state
  defp initial_state, do: %{messages: dummy_messages(), loading: false}

  def mount(_params, _session, socket) do
    {:ok, pid} = Chatgpt.Openai.start_link([])

    {:ok,
     socket
     |> assign(%{openai_pid: pid})
     |> assign(initial_state())}
  end

  def handle_info({:set_error, msg}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, msg)
     |> push_event("newmessage", %{})}
  end

  def handle_info(:unset_error, socket) do
    {:noreply,
     socket
     |> clear_flash(:error)
     |> push_event("newmessage", %{})}
  end

  def handle_info({:add_message, msg}, socket) do
    new_id = Enum.count(socket.assigns.messages) + 1
    msg = Map.put(msg, :id, new_id)

    {:noreply,
     socket
     |> assign(%{messages: socket.assigns.messages ++ [msg]})
     |> push_event("newmessage", %{})}
  end

  def handle_info({:update_messages, msgs}, socket) do
    {:noreply, assign(socket, %{messages: msgs})}
  end

  def handle_info(:stop_loading, socket) do
    {:noreply, assign(socket, %{loading: false})}
  end

  def handle_info({:msg_submit, text}, socket) do
    self = self()

    Process.send(
      self,
      {:add_message, %Message{content: text, sender: :user, id: 0}},
      []
    )

    spawn(fn ->
      case Chatgpt.Openai.send(socket.assigns.openai_pid, text) do
        {:ok, result} ->
          Process.send(self, {:add_message, result}, [])
          Process.send(self, :stop_loading, [])

        {:error, e} ->
          IO.puts("error")
          IO.inspect(e)

          Process.send(self, {:set_error, "#{inspect(e)}"}, [])
          Process.send(self, :stop_loading, [])
      end
    end)

    {:noreply, socket |> assign(:loading, true) |> clear_flash()}
  end

  def render(assigns) do
    ~H"""
    <div id="chatgpt">
      <div class="mb-64 overflow-hidden">
        <.live_component
          module={ChatgptWeb.MessageListComponent}
          messages={assigns.messages}
          id="myid"
        />

        <%= if Phoenix.Flash.get(@flash, :error) do %>
          <div class="container mx-auto p-4">
            <AlertComponent.render text={Phoenix.Flash.get(@flash, :error)} />
          </div>
        <% end %>

        <%= if true == @loading do %>
          <div class="container mx-auto p-4">
            <LoadingIndicatorComponent.render />
          </div>
        <% end %>
      </div>
      <div class="fixed bottom-0 left-0 w-full border-t md:border-t-0 dark:border-white/20 md:border-transparent md:dark:border-transparent md:bg-vert-light-gradient bg-white dark:bg-gray-800 md:!bg-transparent dark:md:bg-vert-dark-gradient pt-2">
        <.live_component
          on_submit={fn val -> Process.send(self(), {:msg_submit, val}, []) end}
          module={ChatgptWeb.TextboxComponent}
          disabled={@loading}
          id="textbox"
        />
      </div>
    </div>
    """
  end
end
