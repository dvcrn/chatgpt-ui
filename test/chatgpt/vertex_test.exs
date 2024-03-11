defmodule Chatgpt.VertexTest do
  use ExUnit.Case

  test "system counts as user" do
    messages = [
      %Chatgpt.Message{sender: :system, content: "Welcome!"},
      %Chatgpt.Message{sender: :user, content: "Hello"},
      %Chatgpt.Message{sender: :user, content: "How are you?"},
      %Chatgpt.Message{sender: :assistant, content: "I am fine, thank you."},
      %Chatgpt.Message{sender: :user, content: "That's good to hear."}
    ]

    expected_messages = [
      %Chatgpt.Message{sender: :system, content: "Welcome!"},
      %Chatgpt.Message{sender: :assistant, content: "ok"},
      %Chatgpt.Message{sender: :user, content: "Hello"},
      %Chatgpt.Message{sender: :assistant, content: "ok"},
      %Chatgpt.Message{sender: :user, content: "How are you?"},
      %Chatgpt.Message{sender: :assistant, content: "I am fine, thank you."},
      %Chatgpt.Message{sender: :user, content: "That's good to hear."}
    ]

    assert Chatgpt.Vertex.fix_messages(messages) == expected_messages
  end

  test "user followed by user msg" do
    messages = [
      %Chatgpt.Message{sender: :user, content: "Hello"},
      %Chatgpt.Message{sender: :user, content: "How are you?"},
      %Chatgpt.Message{sender: :assistant, content: "I am fine, thank you."},
      %Chatgpt.Message{sender: :user, content: "That's good to hear."},
      %Chatgpt.Message{sender: :user, content: "What are you up to today?"}
    ]

    expected_messages = [
      %Chatgpt.Message{sender: :user, content: "Hello"},
      %Chatgpt.Message{sender: :assistant, content: "ok"},
      %Chatgpt.Message{sender: :user, content: "How are you?"},
      %Chatgpt.Message{sender: :assistant, content: "I am fine, thank you."},
      %Chatgpt.Message{sender: :user, content: "That's good to hear."},
      %Chatgpt.Message{sender: :assistant, content: "ok"},
      %Chatgpt.Message{sender: :user, content: "What are you up to today?"}
    ]

    assert Chatgpt.Vertex.fix_messages(messages) == expected_messages
  end

  test "assistant followed by assistant message" do
    messages = [
      %Chatgpt.Message{sender: :assistant, content: "Hello"},
      %Chatgpt.Message{sender: :assistant, content: "How are you?"},
      %Chatgpt.Message{sender: :user, content: "I am fine, thank you."},
      %Chatgpt.Message{sender: :assistant, content: "That's good to hear."},
      %Chatgpt.Message{sender: :assistant, content: "What are you up to today?"}
    ]

    expected_messages = [
      %Chatgpt.Message{sender: :assistant, content: "Hello"},
      %Chatgpt.Message{sender: :user, content: "ok"},
      %Chatgpt.Message{sender: :assistant, content: "How are you?"},
      %Chatgpt.Message{sender: :user, content: "I am fine, thank you."},
      %Chatgpt.Message{sender: :assistant, content: "That's good to hear."},
      %Chatgpt.Message{sender: :user, content: "ok"},
      %Chatgpt.Message{sender: :assistant, content: "What are you up to today?"}
    ]

    assert Chatgpt.Vertex.fix_messages(messages) == expected_messages
  end
end
