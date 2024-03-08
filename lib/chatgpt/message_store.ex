defmodule Chatgpt.MessageStore do
  use Agent
  require Logger

  @spec start_link([Chatgpt.Message.t()]) :: {:ok, pid} | {:error, any()}
  def start_link(initial_messages \\ []) do
    # add id to each message
    initial_messages =
      Enum.with_index(initial_messages, 1)
      |> Enum.map(fn {msg, i} -> Map.put(msg, :id, i) end)

    Agent.start_link(fn -> initial_messages end)
  end

  @spec add_message(pid, %Chatgpt.Message{}) :: :ok
  def add_message(pid, message) do
    next_id = get_next_id(pid)
    Agent.update(pid, fn messages -> [Map.put(message, :id, next_id) | messages] end)
  end

  @spec get_messages(pid) :: [%Chatgpt.Message{}]
  def get_messages(pid) do
    Agent.get(pid, fn messages -> Enum.reverse(messages) end)
  end

  def get_recent_messages(pid, x) do
    Agent.get(pid, fn messages -> Enum.take(messages, x) end)
  end

  @spec get_next_id(pid) :: integer()
  def get_next_id(pid) do
    Agent.get(pid, fn messages -> length(messages) end) + 1
  end
end
