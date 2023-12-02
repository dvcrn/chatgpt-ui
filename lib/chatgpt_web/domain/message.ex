defmodule ChatgptWeb.Message do
  defstruct [:sender, :content, :id]
  @enforce_keys [:sender, :content]

  @type t :: %__MODULE__{
          sender: :user | :assistant | :system,
          content: String.t(),
          id: integer()
        }
end
