defmodule ChatgptWeb.AlertComponent do
  use Phoenix.Component

  attr :text, :string, required: true

  def render(assigns) do
    ~H"""
    <div
      class="flex p-4 mb-4 text-sm text-red-800 border border-red-300 rounded-lg bg-red-50 dark:bg-gray-800 dark:text-red-400 dark:border-red-800"
      role="alert"
    >
      <svg
        aria-hidden="true"
        class="flex-shrink-0 inline w-5 h-5 mr-3"
        fill="currentColor"
        viewBox="0 0 20 20"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          fill-rule="evenodd"
          d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
          clip-rule="evenodd"
        >
        </path>
      </svg>
      <span class="sr-only">Info</span>
      <div>
        <span class="font-medium">Error!</span>
        <%= @text %>
      </div>
    </div>
    """
  end
end
