defmodule Chatgpt.Tokenizer do
  use GenServer
  require Logger

  @model "bert-base-multilingual-uncased"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    Logger.info("downloading tokenizer model: #{@model}")

    case Tokenizers.Tokenizer.from_pretrained(@model) do
      {:ok, tokenizer} -> {:ok, tokenizer}
      {:error, e} -> {:error, e}
    end
  end

  def handle_call({:count_tokens, input}, _from, tokenizer) do
    case Tokenizers.Tokenizer.encode(
           tokenizer,
           input,
           add_special_tokens: false
         ) do
      {:ok, encoding} ->
        {:reply, {:ok, Tokenizers.Encoding.get_tokens(encoding) |> Enum.count()}, tokenizer}

      {:error, e} ->
        {:reply, {:error, e}, tokenizer}
    end
  end

  def count_tokens(input) do
    GenServer.call(__MODULE__, {:count_tokens, input})
  end

  def count_tokens!(input) do
    {:ok, tokens} = GenServer.call(__MODULE__, {:count_tokens, input})
    tokens
  end
end
