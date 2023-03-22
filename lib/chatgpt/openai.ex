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

  @impl true
  def handle_call({:msg, m}, from, msgs) do
    with msgs <- msgs ++ [new_msg(m)] do
      case ExOpenAI.Chat.create_chat_completion(msgs, @model) do
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
              handle_call({:msg, m}, from, msgs)

            false ->
              {:error, msg}
          end

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
