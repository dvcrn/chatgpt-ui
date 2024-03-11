defmodule ChatgptWeb.IndexLive do
  alias Chatgpt.Message
  alias ChatgptWeb.LoadingIndicatorComponent
  alias ChatgptWeb.AlertComponent
  use ChatgptWeb, :live_view

  @type state :: %{messages: [Message.t()], loading: boolean(), streaming_message: Message.t()}

  @spec dummy_messages() :: [Message.t()]
  defp dummy_messages,
    do: [
      %Message{content: "Hi there! How can I assist you today?", sender: :assistant, id: 0}
    ]

  @spec initial_state() :: state
  defp initial_state,
    do: %{
      dummy_messages: dummy_messages() |> fill_random_id(),
      prepend_messages: [],
      messages: [],
      loading: false,
      streaming_message: %Message{content: "", sender: :assistant, id: -1}
    }

  defp fill_random_id(messages),
    do: Enum.map(messages, fn msg -> Map.put(msg, :id, :rand.uniform() |> Float.to_string()) end)

  defp to_atom(s) when is_atom(s), do: s
  defp to_atom(s) when is_binary(s), do: String.to_atom(s)

  defp atom_to_string(s) when is_atom(s), do: Atom.to_string(s)
  defp atom_to_string(s) when is_binary(s), do: s

  def mount(
        _params,
        %{"model" => model, "models" => models, "mode" => :scenario, "scenario" => scenario} =
          session,
        socket
      ) do
    {:ok, pid} = Chatgpt.MessageStore.start_link([])

    selected_model =
      case scenario do
        %{force_model: force_model_id} ->
          atom_to_string(force_model_id)

        _ ->
          model
      end

    {:ok,
     socket
     |> assign(initial_state())
     |> assign(%{
       #  openai_pid: pid,
       message_store_pid: pid,
       prepend_messages: scenario.messages,
       dummy_messages:
         [
           %Chatgpt.Message{content: scenario.description, sender: :assistant, id: 0}
         ]
         |> fill_random_id(),
       model: selected_model,
       models: models,
       active_model: Enum.find(models, &(&1.id == to_atom(selected_model))),
       scenarios: Map.get(session, "scenarios"),
       scenario: scenario,
       mode: :scenario
     })}
  end

  def mount(_params, %{"model" => model, "models" => models} = session, socket) do
    # {:ok, pid} = Chatgpt.Openai.start_link(%{})
    {:ok, pid} = Chatgpt.MessageStore.start_link([])

    {:ok,
     socket
     |> assign(%{
       #  openai_pid: pid,
       model: model,
       message_store_pid: pid,
       dummy_messages: dummy_messages() |> fill_random_id(),
       active_model: Enum.find(models, &(&1.id == to_atom(model))),
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

  def handle_info(:sync_messages, socket) do
    msgs = Chatgpt.MessageStore.get_messages(socket.assigns.message_store_pid)

    {:noreply,
     socket
     |> assign(%{messages: msgs})
     |> push_event("newmessage", %{})}
  end

  def handle_info({:handle_stream_chunk, nil}, socket) do
    {:noreply, socket}
  end

  def handle_info({:handle_stream_chunk, text}, socket) do
    streaming_message =
      socket.assigns.streaming_message
      |> Map.put(:content, socket.assigns.streaming_message.content <> text)

    {:noreply,
     socket
     |> assign(streaming_message: streaming_message)}
  end

  def handle_info(:commit_streaming_message, socket) do
    msg = socket.assigns.streaming_message

    Chatgpt.MessageStore.add_message(socket.assigns.message_store_pid, %Chatgpt.Message{
      content: msg.content,
      sender: :assistant,
      id: Chatgpt.MessageStore.get_next_id(socket.assigns.message_store_pid)
    })

    Process.send(self(), :stop_loading, [])
    Process.send(self(), :sync_messages, [])

    {:noreply,
     socket
     |> assign(%{
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

    # add new message to messagestore
    Chatgpt.MessageStore.add_message(socket.assigns.message_store_pid, %Chatgpt.Message{
      content: text,
      sender: :user
    })

    Process.send(self, :sync_messages, [])

    handle_chunk_callback = fn
      # callback for stream finished
      :finish ->
        Process.send(self, :commit_streaming_message, [])

      # callback for delta data
      {:data, data} ->
        Process.send(self, {:handle_stream_chunk, data}, [])

      {:error, err} ->
        Process.send(self, {:set_error, "#{inspect(err)}"}, [])
        Process.send(self, :stop_loading, [])
    end

    messages =
      case socket.assigns.mode do
        :chat ->
          socket.assigns.prepend_messages ++
            Chatgpt.MessageStore.get_messages(socket.assigns.message_store_pid)

        :scenario ->
          case socket.assigns.scenario.keep_context do
            true ->
              socket.assigns.prepend_messages ++
                Chatgpt.MessageStore.get_messages(socket.assigns.message_store_pid)

            false ->
              socket.assigns.prepend_messages ++
                Chatgpt.MessageStore.get_recent_messages(socket.assigns.message_store_pid, 1)
          end
      end

    llm = Chatgpt.LLM.get_provider(socket.assigns.active_model.provider)
    llm.do_complete(messages, model, handle_chunk_callback)

    {:noreply, socket |> assign(:loading, true) |> clear_flash()}
  end

  def render(assigns) do
    ~H"""
    <div
      id="chatgpt"
      class="flex overflow-scroll"
      style="height: calc(100vh - 64px); flex-direction: column;"
    >
      <div class="mb-32" style="flex-grow: 1;">
        <div>
          <.live_component
            module={ChatgptWeb.MessageListComponent}
            messages={assigns.dummy_messages ++ assigns.messages ++ [assigns.streaming_message]}
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

      <div class="sticky bottom-4 w-full border-t md:border-t-0 dark:border-white/20 md:border-transparent md:dark:border-transparent md:bg-vert-light-gradient bg-white dark:bg-gray-800 md:!bg-transparent dark:md:bg-vert-dark-gradient pt-2">
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
