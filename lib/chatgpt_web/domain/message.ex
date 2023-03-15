defmodule ChatgptWeb.Message do
  defstruct [:sender, :content, :id]
  @enforce_keys [:sender, :content, :id]

  @type t :: %{
          sender: :assistant | :user,
          content: String.t(),
          id: String.t()
        }
end
