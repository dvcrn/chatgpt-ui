defmodule ChatgptWeb.IndexLive do
  alias ChatgptWeb.Message
  alias ChatgptWeb.LoadingIndicatorComponent
  alias ChatgptWeb.AlertComponent
  use ChatgptWeb, :live_view

  use ExOpenAI.StreamingClient

  @type state :: %{messages: [Message.t()], loading: boolean(), streaming_message: Message.t()}

  @spec dummy_messages() :: [Message.t()]
  defp dummy_messages,
    do: [
      %Message{content: "Hi there! How can I assist you today?", sender: :assistant, id: 0}
    ]

  @spec initial_state() :: state
  defp initial_state,
    do: %{
      messages: dummy_messages(),
      loading: false,
      streaming_message: %Message{content: "", sender: :assistant, id: -1}
    }

  def mount(
        _params,
        %{"model" => model, "models" => models, "mode" => :scenario, "scenario" => scenario} =
          session,
        socket
      ) do
    {:ok, pid} =
      Chatgpt.Openai.start_link(%{
        messages: scenario.messages,
        keep_context: Map.get(scenario, "keep_context", false)
      })

    {:ok,
     socket
     |> assign(initial_state())
     |> assign(%{
       openai_pid: pid,
       model: model,
       models: models,
       scenarios: Map.get(session, "scenarios"),
       scenario: scenario,
       mode: :scenario,
       messages: [%ChatgptWeb.Message{content: scenario.description, sender: :assistant, id: 0}]
     })}
  end

  def mount(_params, %{"model" => model, "models" => models} = session, socket) do
    {:ok, pid} = Chatgpt.Openai.start_link(%{})

    {:ok,
     socket
     |> assign(%{
       openai_pid: pid,
       model: model,
       models: models,
       scenarios: Map.get(session, "scenarios"),
       mode: :chat
     })
     |> assign(initial_state())}
  end

  def handle_event(ev, params, socket) do
    IO.puts("handle event")
    IO.inspect(ev)
    IO.inspect(params)
    IO.inspect(socket)
  end

  # -- sse client

  @spec parse_choices(any) :: String.t()
  defp parse_choices(%{text: content}) do
    content
  end

  defp parse_choices(%{delta: %{content: content}}) do
    content
  end

  defp parse_choices(choices) when is_list(choices) do
    List.first(choices)
    |> parse_choices()
  end

  defp parse_choices(_) do
    ""
  end

  def handle_data(%{id: _id, choices: choices}, state) do
    streamed_text = parse_choices(choices)

    streaming_message =
      state.assigns.streaming_message
      |> Map.put(:content, state.assigns.streaming_message.content <> streamed_text)

    {:noreply,
     state
     |> assign(streaming_message: streaming_message)}
  end

  def handle_error(e, state) do
    IO.puts("got error: #{inspect(e)}")
    Process.send(self(), {:set_error, "#{inspect(e)}"}, [])
    Process.send(self, :stop_loading, [])

    {:noreply, state}
  end

  def handle_finish(state) do
    # swap streaming message into a real message
    Process.send(
      self(),
      {:commit_streaming_message, state.assigns.streaming_message},
      []
    )

    {:noreply, state}
  end

  # -- sse client

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

  def handle_info({:commit_streaming_message, msg}, socket) do
    new_id = Enum.count(socket.assigns.messages) + 1
    msg = Map.put(msg, :id, new_id)

    # insert into stateful openai container so we have history
    Chatgpt.Openai.insert_message(socket.assigns.openai_pid, msg)

    Process.send(self(), :stop_loading, [])

    {:noreply,
     socket
     |> assign(%{
       messages: socket.assigns.messages ++ [msg],
       streaming_message: %Message{content: "", sender: :assistant, id: -1}
     })
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

    model = Map.get(socket.assigns, :model)

    Process.send(
      self,
      {:add_message, %Message{content: text, sender: :user, id: 0}},
      []
    )

    spawn(fn ->
      case Chatgpt.Openai.send(socket.assigns.openai_pid, text, model, self) do
        {:ok, result} when is_reference(result) ->
          nil

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
    <div id="chatgpt" class="flex" style="height: calc(100vh - 64px); flex-direction: column;">
      <div class="mb-32" style="flex-grow: 1;">
        <div>
        <.live_component
          module={ChatgptWeb.MessageListComponent}
          messages={assigns.messages ++ [assigns.streaming_message]}
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
      </div>

      <div class="sticky bottom-4 w-full border-t md:border-t-0 dark:border-white/20 md:border-transparent md:dark:border-transparent md:bg-vert-light-gradient bg-white dark:bg-gray-800 md:!bg-transparent dark:md:bg-vert-dark-gradient pt-2" >
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
