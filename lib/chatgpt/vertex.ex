defmodule Chatgpt.Vertex do
  @behaviour Chatgpt.LLM

  # Set the base URL for the Vertex AI API
  @base_url "https://us-central1-aiplatform.googleapis.com"

  # Initialize the client
  # def new do
  #   Tesla.client([
  #     {Tesla.Middleware.BaseUrl, @base_url},
  #     {Tesla.Middleware.JSON, engine: Jason}
  #   ])
  # end

  def new do
    Finch.start_link(name: __MODULE__)
  end

  # Make the API request to streamGenerateContent
  # def stream_generate_content(client, project_id, model_id, contents) do
  #   with {:ok, %{token: token}} <-
  #          Goth.Token.for_scope("https://www.googleapis.com/auth/cloud-platform") do
  #     client
  #     |> Tesla.post(
  #       "/v1/projects/#{project_id}/locations/us-central1/publishers/google/models/#{model_id}:streamGenerateContent",
  #       %{
  #         "contents" => contents
  #       },
  #       headers: [
  #         {"Authorization", "Bearer #{token}"},
  #         {"Content-Type", "application/json"}
  #       ]
  #     )
  #   end
  # end

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

          %{"finishReason" => finishReason} ->
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
      Enum.map(messages, fn msg ->
        %{
          "role" => msg.sender,
          "parts" => %{
            "text" => msg.content
          }
        }
      end)

    spawn(fn ->
      stream_generate_content_streaming(project_id, model, contents, fx)
    end)

    :ok
  end
end
