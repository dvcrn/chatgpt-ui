defmodule Chatgpt.MessageStore do
  use Agent
  require Logger

  def start_link(_) do
    Agent.start_link(fn -> [] end)
  end

  @spec add_message(pid, %Chatgpt.Message{}) :: :ok
  def add_message(pid, message) do
    Logger.info("Adding message to store: #{inspect(message)}")
    Agent.update(pid, fn messages -> [message | messages] end)
  end

  @spec get_messages(pid) :: [%Chatgpt.Message{}]
  def get_messages(pid) do
    Agent.get(pid, fn messages -> Enum.reverse(messages) end)
  end

  def get_recent_messages(pid, x) do
    Agent.get(pid, fn messages -> Enum.take(Enum.reverse(messages), x) end)
  end

  @spec get_next_id(pid) :: integer()
  def get_next_id(pid) do
    Agent.get(pid, fn messages -> length(messages) end) + 1
  end
end
