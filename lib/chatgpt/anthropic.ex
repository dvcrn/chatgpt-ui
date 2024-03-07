defmodule Chatgpt.Anthropic do
  defmodule Message do
    @derive Jason.Encoder

    defmodule TextContent do
      @derive Jason.Encoder

      @enforce_keys [:type, :text]
      defstruct [:type, :text]

      @type t :: %__MODULE__{
              type: :text,
              text: String.t()
            }
    end

    @enforce_keys [:role, :content]
    defstruct [:role, :content]

    @type t :: %__MODULE__{
            role: :assistant | :user,
            content: String.t()
          }
  end

  defp client do
    IO.inspect(Application.get_env(:chatgpt, :access_key_id, ""))
    IO.inspect(Application.get_env(:chatgpt, :secret_access_key, ""))
    IO.inspect(Application.get_env(:chatgpt, :region, ""))

    AWS.Client.create(
      Application.get_env(:chatgpt, :access_key_id, ""),
      Application.get_env(:chatgpt, :secret_access_key, ""),
      Application.get_env(:chatgpt, :region, "")
    )
    |> AWS.Client.put_http_client(
      {Chatgpt.HTTPClient.StreamingFinch, [finch_name: Chatgpt.Finch]}
    )
  end

  @doc """
  Iterate over all messages and make sure that in between each :user message, there is an :assistant message.
  """
  def fix_messages(messages) when is_list(messages) do
    # create agent for keeping track of state of previous message
    {:ok, agent} =
      Agent.start_link(fn -> nil end)

    # iterate over all messages and fix them
    Enum.reduce(messages, [], fn msg, acc ->
      prev_role = Agent.get(agent, & &1)
      should_insert = prev_role == :user && msg.role == :user

      Agent.update(agent, fn _ -> msg.role end)

      case should_insert do
        true -> [%Chatgpt.Anthropic.Message{role: :assistant, content: ""} | [msg | acc]]
        false -> [msg | acc]
      end
    end)
    |> Enum.drop_while(fn msg -> msg.role == :assistant end)
    |> Enum.reverse()

    # # if last message is from :assistant, delete it
    # |> Enum.reverse()
    # |> Enum.reverse()
  end

  @spec convert_message(Chatgpt.Message.t()) :: Chatgpt.Anthropic.Message.t()
  def convert_message(%Chatgpt.Message{sender: :user} = msg) do
    %Chatgpt.Anthropic.Message{
      content: msg.content,
      role: :user
    }
  end

  def convert_message(%Chatgpt.Message{sender: :assistant} = msg) do
    %Chatgpt.Anthropic.Message{
      content: msg.content,
      role: :assistant
    }
  end

  @spec do_complete([Chatgpt.Messages], Chatgpt.LLM.chunk()) :: :ok | {:error, String.t()}
  def do_complete(messages, callback) do
    converted_msgs =
      Enum.map(messages, &convert_message/1)
      |> IO.inspect()
      |> fix_messages()
      |> IO.inspect()

    # prompt =
    #   messages
    #   |> Enum.map(fn
    #     %{content: content, sender: :assistant} ->
    #       nil
    #       "Assistant: #{content}"

    #     %{content: content, sender: :user} ->
    #       "Human: #{content}"
    #   end)
    #   |> Enum.join("\n\n")

    # prompt = prompt <> "\n\nAssistant:"

    streamhandler = fn
      {:status, status}, acc ->
        IO.inspect("Download assets status: #{status}")

      {:headers, headers}, acc ->
        IO.inspect("Download assets headers: #{inspect(headers)}")

      {:data, data}, acc ->
        <<total_byte_length::binary-size(4), headers_byte_length::binary-size(4),
          _prelude_crc::binary-size(4),
          rest::binary>> =
          data

        # IO.puts("total byte length: #{inspect(total_byte_length)}")
        # IO.puts("header byte length: #{inspect(headers_byte_length)}")

        # https://docs.aws.amazon.com/transcribe/latest/dg/streaming-setting-up.html#streaming-event-stream
        # 32 because uint32
        <<headers_size::32>> = headers_byte_length
        <<total_size::32>> = total_byte_length
        payload_size = total_size - headers_size - 4 - 4 - 4 - 4

        <<_::binary-size(headers_size), data_without_headers::binary>> = rest

        # chop off the payload size only, and leave the rest
        <<payload::binary-size(payload_size), _::binary>> = data_without_headers

        decoded_payload =
          payload
          |> IO.inspect()
          |> Jason.decode!()
          |> Map.get("bytes")
          |> IO.inspect()
          |> Base.decode64!()
          |> IO.inspect()
          |> Jason.decode!()
          |> IO.inspect()

        case decoded_payload do
          %{"message" => %{"content" => completion, "stop_reason" => stop_reason}} ->
            IO.inspect("got message: #{inspect(completion)}")

          # %{
          # 	"delta" => %{"text" => "My", "type" => "text_delta"},
          # 	"index" => 0,
          # 	"type" => "content_block_delta"
          # }
          %{"delta" => %{"text" => text_delta}} ->
            IO.inspect("got delta")
            callback.({:data, text_delta})

          # %{
          # 	"delta" => %{"stop_reason" => "end_turn", "stop_sequence" => nil},
          # 	"type" => "message_delta",
          # 	"usage" => %{"output_tokens" => 15}
          # }
          %{"delta" => %{"stop_reason" => _}} ->
            callback.(:finish)

          _ ->
            IO.inspect("got unknown message")
        end

        # case stop_reason do
        #   nil ->
        #     callback.({:data, completion})

        #   _text ->
        #     callback.({:data, completion})
        #     callback.(:finish)
        # end

        data
    end

    opts = [
      {:recv_timeout, 500_000},
      {:contentType, "application/json"},
      {:streamfx, streamhandler}
    ]

    req = %{
      "contentType" => "application/json",
      # "prompt" => prompt,
      "anthropic_version" => "bedrock-2023-05-31",
      "max_tokens" => 10000,
      # "stop_sequences" => ["\\n\\nHuman:"],
      "temperature" => 0.8,
      "messages" => converted_msgs
    }

    IO.puts("invoking model with response stream")
    IO.inspect(req)

    spawn(fn ->
      client()
      |> AWS.BedrockRuntime.invoke_model_with_response_stream(
        "anthropic.claude-3-sonnet-20240229-v1:0",
        req,
        opts
      )
    end)
  end
end
