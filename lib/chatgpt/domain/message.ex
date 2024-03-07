defmodule Chatgpt.Message do
  defstruct [:sender, :content, :id]
  @enforce_keys [:sender, :content]

  @type t :: %__MODULE__{
          sender: :assistant | :user,
          content: String.t(),
          id: integer()
        }
end
