defmodule Chatgpt.Openai do
  use GenServer
  alias ChatgptWeb.Message

  @model Application.compile_env(:chatgpt, :model, "gpt-4")

  @impl true
  def init(_opts) do
    {:ok, []}
  end

  defp new_msg(m) do
    %ExOpenAI.Components.ChatCompletionRequestMessage{
      content: m,
      role: :user,
      name: "user"
    }
  end

  @spec role(String.t()) :: atom()
  defp role(r) when is_binary(r), do: String.to_atom(r)
  @spec role(atom()) :: atom()
  defp role(r) when is_atom(r), do: r

  @spec to_domain(ExOpenAI.Components.ChatCompletionResponseMessage.t()) :: Message.t()
  defp to_domain(msg) do
    %Message{
      content: msg.content,
      sender: role(msg.role),
      id: 0
    }
  end

  @spec from_domain(Message.t()) :: ExOpenAI.Components.ChatCompletionRequestMessage.t()
  defp from_domain(msg) do
    %ExOpenAI.Components.ChatCompletionRequestMessage{
      content: msg.content,
      role: role(msg.sender)
    }
  end

  @impl true
  def handle_call({:insertmsg, m}, _from, cur_msgs) do
    new_msg = from_domain(m)
    {:reply, new_msg, cur_msgs ++ [new_msg]}
  end

  @impl true
  def handle_call({:msg, m, streamer_pid} = params, from, cur_msgs) do
    with msgs <- cur_msgs ++ [new_msg(m)] do
      case ExOpenAI.Chat.create_chat_completion(msgs, @model,
             temperature: 0.8,
             stream: true,
             stream_to: streamer_pid
           ) do
        {:ok, res} when is_reference(res) ->
          {:reply, {:ok, res}, msgs}

        {:ok, res} ->
          first = List.first(res.choices)
          combined = msgs ++ [first.message]
          {:reply, {:ok, to_domain(first.message)}, combined}

        {:error, %{"error" => %{"message" => msg}}} ->
          case(
            # if this specific error, retry
            String.contains?(
              msg,
              "The server had an error while processing your request. Sorry about that!"
            )
          ) do
            true ->
              handle_call(params, from, cur_msgs)

            false ->
              {:reply, {:error, msg}, cur_msgs}
          end

        {:error, reason} ->
          {:reply, {:error, reason}, cur_msgs}
      end
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def send(pid, msg, streamer_pid) do
    GenServer.call(pid, {:msg, msg, streamer_pid}, 100_000)
  end

  def insert_message(pid, msg) do
    GenServer.call(pid, {:insertmsg, msg}, 100_000)
  end
end
