defmodule ChatgptWeb.IndexLive do
  alias ChatgptWeb.Message
  use ChatgptWeb, :live_view

  @type state :: %{messages: [Message.t()]}

  defp dummy_messages,
    do: [
      %Message{content: "Hi there! Ask me something :)", sender: :assistant, id: "1"}
      # %Message{content: "Whats up", sender: :user, id: "3"},
      # %Message{content: @longcontent, sender: :assistant, id: "2"}
    ]

  def mount(_params, _session, socket) do
    {:ok, pid} = Chatgpt.Openai.start_link([])

    {:ok,
     socket
     |> assign(%{messages: dummy_messages(), openai_pid: pid})}
  end

  def handle_info({:add_message, msg}, socket) do
    {:noreply,
     socket
     |> assign(%{messages: socket.assigns.messages ++ [msg]})
     |> push_event("newmessage", %{})}
  end

  def handle_info({:update_messages, msgs}, socket) do
    {:noreply, assign(socket, %{messages: msgs})}
  end

  def handle_info({:msg_submit, text}, socket) do
    IO.puts("submit msg")
    IO.inspect(text)
    IO.inspect(socket)

    self = self()

    Process.send(
      self,
      {:add_message, %Message{content: text, sender: :user, id: :rand.uniform(256) - 1}},
      []
    )

    spawn(fn ->
      case Chatgpt.Openai.send(socket.assigns.openai_pid, text) do
        {:ok, result} ->
          IO.puts("result")
          IO.inspect(result)
          Process.send(self, {:add_message, result}, [])

        {:error, e} ->
          IO.puts("error")
          IO.inspect(e)
          %{error: e}
      end
    end)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-64 overflow-hidden">
        <.live_component
          module={ChatgptWeb.MessageListComponent}
          messages={assigns.messages}
          id="myid"
        />
      </div>
      <div class="fixed bottom-0 left-0 w-full border-t md:border-t-0 dark:border-white/20 md:border-transparent md:dark:border-transparent md:bg-vert-light-gradient bg-white dark:bg-gray-800 md:!bg-transparent dark:md:bg-vert-dark-gradient pt-2">
        <.live_component
          on_submit={fn val -> Process.send(self(), {:msg_submit, val}, []) end}
          module={ChatgptWeb.TextboxComponent}
          id="textbox"
        />
      </div>
    </div>
    """
  end
end
