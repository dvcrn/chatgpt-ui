defmodule ChatgptWeb.Layouts do
  use ChatgptWeb, :html

  def active_scenario(nil, scenario), do: ""

  def active_scenario(active_scenario, scenario) do
    if active_scenario.id == scenario.id do
      "active"
    else
      ""
    end
  end

  embed_templates("layouts/*")
end
