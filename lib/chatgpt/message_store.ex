defmodule Chatgpt.MessageStore do
  use Agent
  require Logger

  def start_link(_) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  @spec add_message(%Chatgpt.Message{}) :: :ok
  def add_message(message) do
    Logger.info("Adding message to store: #{inspect(message)}")
    Agent.update(__MODULE__, fn messages -> [message | messages] end)
  end

  @spec get_messages() :: [%Chatgpt.Message{}]
  def get_messages do
    Agent.get(__MODULE__, fn messages -> Enum.reverse(messages) end)
  end

  def get_recent_messages(x) do
    Agent.get(__MODULE__, fn messages -> Enum.take(Enum.reverse(messages), x) end)
  end

  @spec get_next_id() :: integer()
  def get_next_id do
    Agent.get(__MODULE__, fn messages -> length(messages) end) + 1
  end
end
