defmodule ChatgptWeb.PageController do
  use ChatgptWeb, :controller

  defp protect_with_session(conn, _params, fx) do
    case get_session(conn) do
      %{"oauth_google_token" => _token, "oauth_expiration" => expiration} ->
        if DateTime.compare(DateTime.now!("Etc/UTC"), expiration) == :gt do
          oauth_google_url = ElixirAuthGoogle.generate_oauth_url(conn)
          redirect(conn, external: oauth_google_url)
        else
          fx.()
        end

      _ ->
        oauth_google_url = ElixirAuthGoogle.generate_oauth_url(conn)
        redirect(conn, external: oauth_google_url)
    end
  end

  defp render_page(conn, params, args) do
    default_model = Application.get_env(:chatgpt, :default_model, :"gpt-3.5-turbo")

    session_model =
      case get_session(conn) do
        %{"model" => model} ->
          model

        _ ->
          default_model
      end

    model =
      case Map.get(params, "model", nil) do
        nil -> session_model
        m -> m
      end

    args =
      Map.merge(
        %{
          "model" => model,
          "models" => Application.get_env(:chatgpt, :models, [model]),
          "scenarios" => ChatgptWeb.Scenario.default_scenarios()
        },
        args
      )

    conn = put_session(conn, "model", Map.get(params, "model", model))

    if Application.get_env(:chatgpt, :enable_google_oauth, false) do
      protect_with_session(
        conn,
        params,
        fn ->
          live_render(conn, ChatgptWeb.IndexLive, session: args)
        end
      )
    else
      live_render(conn, ChatgptWeb.IndexLive, session: args)
    end
  end

  def chat(conn, params) do
    render_page(conn, params, %{"mode" => :chat})
  end

  def scenario(conn, params) do
    scenario =
      ChatgptWeb.Scenario.default_scenarios()
      |> Enum.find(fn sc -> sc.id == Map.get(params, "scenario_id", nil) end)

    render_page(conn, params, %{} |> Map.put("mode", :scenario) |> Map.put("scenario", scenario))
  end

  def oauth_callback(conn, %{"code" => code}) do
    with {:ok, token} <- ElixirAuthGoogle.get_token(code, conn),
         %{access_token: access_token} <- token,
         {:ok, profile} <- ElixirAuthGoogle.get_user_profile(access_token),
         %{email: email} <- profile,
         %{expires_in: expires_in} <- token,
         restrict_email_domains? <-
           Application.get_env(:chatgpt, :restrict_email_domains, false),
         allowed_email_domains <-
           Application.get_env(:chatgpt, :allowed_email_domains, []) do
      cond do
        # restrict_email_domains set, and domain is found
        restrict_email_domains? and
            Enum.find(allowed_email_domains, &String.contains?(email, &1)) == nil ->
          {:error, "email not allowed"}

        true ->
          :ok
      end
      |> case do
        :ok ->
          expiry_datetime = DateTime.add(DateTime.now!("Etc/UTC"), expires_in, :second)

          conn
          |> put_session("oauth_google_token", token)
          |> put_session("oauth_expiration", expiry_datetime)
          |> put_session("google_profile", profile)
          |> redirect(to: "/")

        {:error, msg} ->
          text(conn, "authorization failed: #{msg}")
      end
    else
      err ->
        text(conn, "authorization failed: #{inspect(err)}")
    end
  end
end
