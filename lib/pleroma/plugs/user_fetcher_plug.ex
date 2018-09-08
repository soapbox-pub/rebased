defmodule Pleroma.Plugs.UserFetcherPlug do
  import Plug.Conn
  alias Pleroma.Repo
  alias Pleroma.User

  def init(options) do
    options
  end

  def call(conn, options) do
    with %{auth_credentials: %{username: username}} <- conn.assigns,
         {:ok, %User{} = user} <- user_fetcher(username) do
      conn
      |> assign(:auth_user, user)
    else
      _ -> conn
    end
  end

  defp user_fetcher(username_or_email) do
    {
      :ok,
      cond do
        # First, try logging in as if it was a name
        user = Repo.get_by(User, %{nickname: username_or_email}) ->
          user

        # If we get nil, we try using it as an email
        user = Repo.get_by(User, %{email: username_or_email}) ->
          user
      end
    }
  end
end
