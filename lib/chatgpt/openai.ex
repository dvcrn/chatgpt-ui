defmodule Chatgpt.Openai do
  use GenServer
  alias ExOpenAI.Components.ChatCompletionRequestMessage
  alias ExOpenAI.Components.ChatCompletionResponseMessage
  alias ChatgptWeb.Message

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

  defp role(r) when is_binary(r), do: String.to_atom(r)
  defp role(r) when is_atom(r), do: r

  @spec to_domain(ChatCompletionRequestMessage.t()) :: Message.t()
  defp to_domain(msg) do
    %Message{
      content: msg.content,
      sender: role(msg.role),
      id: "#{:rand.uniform(256) - 1}"
    }
  end

  @impl true
  def handle_call({:msg, m}, _from, msgs) do
    with msgs <- msgs ++ [new_msg(m)] do
      case ExOpenAI.Chat.create_chat_completion(msgs, "gpt-4") do
        {:ok, res} ->
          first = List.first(res.choices)
          combined = msgs ++ [first.message]
          {:reply, {:ok, to_domain(first.message)}, combined}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def send(pid, msg) do
    GenServer.call(pid, {:msg, msg}, 50000)
  end
end
