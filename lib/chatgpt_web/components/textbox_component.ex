defmodule ChatgptWeb.TextboxComponent do
  use ChatgptWeb, :live_component

  defp new_form(), do: to_form(%{"text" => "", "rand" => UUID.uuid4()}, as: :main)

  def mount(socket) do
    {:ok,
     socket
     |> assign(form: new_form(), text: "")}
  end

  def handle_event("onsubmit", %{"main" => %{"text" => text}}, socket) do
    if String.length(text) >= 2 and socket.assigns.disabled == false do
      socket.assigns.on_submit.(text)
      {:noreply, socket |> assign(form: new_form())}
    else
      {:noreply, socket}
    end
  end

  attr :field, Phoenix.HTML.FormField
  attr :text, :string
  attr :myself, :any
  attr :disabled, :boolean

  def textarea(assigns) do
    assigns =
      assign(assigns, :onkeydown, """
      if(event.keyCode == 13 && event.shiftKey == false) {
      		document.getElementById('submitbtn').click();
      	 return false;}
      """)

    ~H"""
    <textarea
      tabindex="0"
      style="max-height: 200px; height: 96px; overflow-y: hidden;"
      class="m-0 w-full resize-none border-0 bg-transparent p-0 pr-7 focus:ring-0 focus-visible:ring-0 dark:bg-transparent pl-2 md:pl-0"
      placeholder="Enter your message..."
      id={@field.id}
      name={@field.name}
      phx-target={@myself}
      onkeydown={@onkeydown}
    ><%= @field.value %></textarea>
    """
  end

  attr :on_submit, :any, required: true
  attr :disabled, :boolean, required: true

  def render(assigns) do
    ~H"""
    <div id="textbox" class="">
      <p><%= @text %></p>
      <.form
        class="stretch mx-2 flex flex-row gap-3 last:mb-2 md:mx-4 md:last:mb-6 lg:mx-auto lg:max-w-3xl"
        phx-target={@myself}
        phx-submit="onsubmit"
        for={@form}
      >
        <div class="flex flex-col w-full py-2 flex-grow md:py-3 md:pl-4 relative border border-black/10 bg-white dark:border-gray-900/50 dark:text-white dark:bg-gray-700 rounded-md shadow-[0_0_10px_rgba(0,0,0,0.10)] dark:shadow-[0_0_15px_rgba(0,0,0,0.10)]">
          <.textarea disabled={@disabled} field={@form[:text]} myself={@myself} text={@text} />
          <button
            id="submitbtn"
            class="absolute p-1 rounded-md text-gray-500 bottom-1.5 md:bottom-2.5 hover:bg-gray-100 dark:hover:text-gray-400 dark:hover:bg-gray-900 disabled:hover:bg-transparent dark:disabled:hover:bg-transparent right-1 md:right-2"
          >
            <svg
              stroke="currentColor"
              fill="none"
              stroke-width="2"
              viewBox="0 0 24 24"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="h-4 w-4 mr-1"
              height="1em"
              width="1em"
              xmlns="http://www.w3.org/2000/svg"
            >
              <line x1="22" y1="2" x2="11" y2="13"></line>
              <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
            </svg>
          </button>
        </div>
      </.form>
    </div>
    """
  end
end
