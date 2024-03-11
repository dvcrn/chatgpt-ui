defmodule Chatgpt.Vertex do
  @behaviour Chatgpt.LLM

  # Set the base URL for the Vertex AI API
  @base_url "https://us-central1-aiplatform.googleapis.com"

  def new do
    Finch.start_link(name: __MODULE__)
  end

  defp convert_message(%Chatgpt.Message{sender: :assistant, content: content}),
    do: %{
      "role" => "model",
      "parts" => %{
        "text" => content
      }
    }

  defp convert_message(%Chatgpt.Message{sender: :user, content: content}),
    do: %{
      "role" => "user",
      "parts" => %{
        "text" => content
      }
    }

  defp convert_message(%Chatgpt.Message{sender: :system, content: content}),
    do: %{
      "role" => "user",
      "parts" => %{
        "text" => content
      }
    }

  def fix_messages(messages) do
    messages
    |> Enum.reduce([], fn message, acc ->
      case {List.last(acc), message} do
        # Insert assistant between user/system and user messages
        {%Chatgpt.Message{sender: prev_sender}, %Chatgpt.Message{sender: :user}}
        when prev_sender in [:user, :system] ->
          acc ++ [%Chatgpt.Message{sender: :assistant, content: "ok"}, message]

        # Insert assistant between user/system messages if consecutive
        {%Chatgpt.Message{sender: :assistant}, %Chatgpt.Message{sender: next_sender}}
        when next_sender in [:user, :system] ->
          acc ++ [message]

        # Insert user between assistant and assistant messages
        {%Chatgpt.Message{sender: :assistant}, %Chatgpt.Message{sender: :assistant}} ->
          acc ++ [%Chatgpt.Message{sender: :user, content: "ok"}, message]

        # Default case: just append the message
        _ ->
          acc ++ [message]
      end
    end)
  end

  def stream_generate_content(project_id, model_id, contents) do
    with {:ok, %{token: token}} <-
           Goth.Token.for_scope("https://www.googleapis.com/auth/cloud-platform") do
      Finch.build(
        :post,
        "#{@base_url}/v1/projects/#{project_id}/locations/us-central1/publishers/google/models/#{model_id}:streamGenerateContent"
      )
      |> Finch.request(
        Chatgpt.Finch,
        [
          {"Authorization", "Bearer #{token}"},
          {"Content-Type", "application/json"}
        ],
        Jason.encode!(%{
          "contents" => contents
        })
      )
    end
  end

  def stream_generate_content_streaming(project_id, model_id, contents, callback_fx) do
    with {:ok, %{token: token}} <-
           Goth.Token.for_scope("https://www.googleapis.com/auth/cloud-platform") do
      Finch.build(
        :post,
        "#{@base_url}/v1/projects/#{project_id}/locations/us-central1/publishers/google/models/#{model_id}:streamGenerateContent?alt=sse",
        [
          {"Authorization", "Bearer #{token}"},
          {"Content-Type", "application/json"}
        ],
        Jason.encode!(%{
          "contents" => contents
        })
      )
      |> Finch.stream(
        Chatgpt.Finch,
        %{},
        callback_fx,
        []
      )
    end
  end

  @spec do_complete([Chatgpt.Messages], String.t(), Chatgpt.LLM.chunk()) ::
          :ok | {:error, String.t()}
  def do_complete(messages, model, callback) do
    fx = fn
      {:status, status}, _acc ->
        IO.puts("Status: #{status}")

      {:headers, headers}, _acc ->
        # IO.puts("Headers: #{inspect(headers)}")
        nil

      {:data, "data: " <> data}, _acc ->
        data
        |> Jason.decode!()
        |> Map.get("candidates")
        |> List.first()
        |> case do
          %{"content" => %{"parts" => parts}, "finishReason" => finishReason} ->
            text_delta = parts |> List.first() |> Map.get("text")

            callback.({:data, text_delta})
            callback.(:finish)
            nil

          %{"finishReason" => _finishReason} ->
            callback.(:finish)

          %{"content" => %{"parts" => parts}} ->
            text_delta = parts |> List.first() |> Map.get("text")
            callback.({:data, text_delta})

          {:error, err} ->
            IO.puts("Error: #{inspect(err)}")
            {:error, err}

          e ->
            IO.puts("unhandled")
            IO.puts("Error: #{inspect(e)}")
        end

      {:data, data}, _acc ->
        IO.puts("unhandled data: #{data}")
    end

    project_id = Application.get_env(:chatgpt, :google_cloud_project_id, "")

    contents =
      messages |> fix_messages() |> Enum.map(&convert_message/1)

    spawn(fn ->
      stream_generate_content_streaming(project_id, model, contents, fx)
    end)

    :ok
  end
end
