defmodule Chatgpt.Openai do
  use GenServer
  alias ChatgptWeb.Message
  require Logger

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
  def handle_call({:msg, m, streamer_pid, "davinci"} = params, from, cur_msgs) do
    Logger.info("completing with davinci")

    with msgs <- cur_msgs ++ [new_msg(m)] do
      default_prompt =
        "This is a conversation between the 'user' and a helpful AI assistant called 'assistant'. Only those 2 users are in the conversation. 'assistant' is also very knowledgeable in programming, and provides long replies that go into extensive detail, in a conversational matter. 'assistant' uses markdown in replies.\n\n"

      default_prompt_tokens = Chatgpt.Tokenizer.count_tokens!(default_prompt)

      prompt =
        msgs
        |> Enum.map(fn msg -> "#{Atom.to_string(msg.role)}: #{msg.content}" end)
        # take the newest messages backwards until hitting the limit
        |> Enum.reverse()
        |> Enum.reduce_while("", fn x, acc ->
          with summarized <- x <> "\n\n" <> acc do
            if Chatgpt.Tokenizer.count_tokens!(summarized) + default_prompt_tokens >= 2200 do
              {:halt, acc}
            else
              {:cont, summarized}
            end
          end
        end)

      prompt = default_prompt <> prompt <> "\n\nassistant:"
      Logger.debug(prompt)

      Logger.debug(
        "prompt size: #{String.length(prompt)} -- #{Chatgpt.Tokenizer.count_tokens!(prompt)} tokens"
      )

      case ExOpenAI.Completions.create_completion("text-davinci-003",
             prompt: prompt,
             temperature: 0.7,
             stream: true,
             stream_to: streamer_pid,
             max_tokens: 2048
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

  @impl true
  def handle_call({:msg, m, streamer_pid, model} = params, from, cur_msgs) do
    Logger.info("completing with #{model}")

    with msgs <- cur_msgs ++ [new_msg(m)] do
      # strip out things that are over the token limit
      filtered_msgs =
        msgs
        |> Enum.reverse()
        |> Enum.reduce_while(%{msgs: [], tokens: 0}, fn msg, acc ->
          with msg_tokens <- Chatgpt.Tokenizer.count_tokens!(msg.content) do
            if msg_tokens + acc.tokens > 4000 do
              {:halt, acc}
            else
              {:cont, %{msgs: acc.msgs ++ [msg], tokens: acc.tokens + msg_tokens}}
            end
          end
        end)

      Logger.debug("prompt size: #{filtered_msgs.tokens} tokens")

      filtered_msgs
      |> Map.get(:msgs)
      |> Enum.reverse()
      |> ExOpenAI.Chat.create_chat_completion(model,
        temperature: 0.8,
        stream: true,
        stream_to: streamer_pid
      )
      |> case do
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

  def send(pid, msg, model, streamer_pid) do
    GenServer.call(pid, {:msg, msg, streamer_pid, model}, 100_000)
  end

  def insert_message(pid, msg) do
    GenServer.call(pid, {:insertmsg, msg}, 100_000)
  end
end
