defmodule Chatgpt.LLM do
  @type chunk :: {:data, String.t()} | {:error, String.t()} | :finish
  @type handle_chunk_fun :: (chunk -> :ok | {:error, String.t()})

  @callback do_complete(list_of_messages :: [Chatgpt.Message], callback :: handle_chunk_fun()) ::
              {:ok, Chatgpt.Message} | {:error, String.t()}

  def get_provider(:anthropic), do: Chatgpt.Anthropic
  def get_provider(:openai), do: Chatgpt.OpenAI2
  def get_provider(_), do: raise("Unknown provider")
end
