defmodule Chatgpt.OpenAI2 do
  @behaviour Chatgpt.LLM

  @spec convert_message(Chatgpt.Message.t()) ::
          ExOpenAI.Components.ChatCompletionRequestUserMessage.t()
          | ExOpenAI.Components.ChatCompletionRequestAssistantMessage.t()
  def convert_message(%Chatgpt.Message{sender: :user} = msg) do
    %ExOpenAI.Components.ChatCompletionRequestUserMessage{
      content: msg.content,
      role: :user
    }
  end

  def convert_message(%Chatgpt.Message{sender: :assistant} = msg) do
    %ExOpenAI.Components.ChatCompletionRequestAssistantMessage{
      content: msg.content,
      role: :assistant
    }
  end

  def convert_message(%Chatgpt.Message{sender: :system} = msg) do
    %ExOpenAI.Components.ChatCompletionRequestAssistantMessage{
      content: msg.content,
      role: :system
    }
  end

  @spec do_complete([Chatgpt.Messages], String.t(), Chatgpt.LLM.chunk()) ::
          :ok | {:error, String.t()}
  def do_complete(messages, model, callback) do
    callback = fn
      :finish ->
        IO.puts("Done")
        callback.(:finish)

      {:data, %ExOpenAI.Components.CreateChatCompletionResponse{choices: choices}} ->
        chunk_text =
          choices
          |> List.first()
          |> Map.get(:delta)
          |> Map.get(:content)

        callback.({:data, chunk_text})

      # {:data, data} ->
      #   IO.puts("Data: #{inspect(data)}")

      {:error, err} ->
        IO.puts("Error: #{inspect(err)}")
        callback.({:error, err})
    end

    IO.inspect(messages)
    converted_msgs = Enum.map(messages, &convert_message/1)

    IO.inspect(converted_msgs)

    IO.puts("hitting gpt4 now")

    case ExOpenAI.Chat.create_chat_completion(converted_msgs, model,
           temperature: 0.8,
           stream: true,
           stream_to: callback
         ) do
      {:ok, reference} ->
        IO.puts("chat_complete: #{inspect(reference)}")
        {:ok, reference}

      {:error, err} ->
        IO.puts("Error: #{inspect(err)}")
        {:error, err}
    end

    :ok
  end
end
