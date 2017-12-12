defmodule Pleroma.Web.TwitterAPI.UtilController do
  use Pleroma.Web, :controller
  alias Pleroma.Web
  alias Pleroma.Formatter
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.{Repo, PasswordResetToken, User}

  def show_password_reset(conn, %{"token" => token}) do
    with %{used: false} = token <- Repo.get_by(PasswordResetToken, %{token: token}),
      %User{} = user <- Repo.get(User, token.user_id) do
      render conn, "password_reset.html", %{
        token: token,
        user: user
      }
    else
      _e -> render conn, "invalid_token.html"
    end
  end

  def password_reset(conn, %{"data" => data}) do
    with {:ok, _} <- PasswordResetToken.reset_password(data["token"], data) do
      render conn, "password_reset_success.html"
    else
      _e -> render conn, "password_reset_failed.html"
    end
  end

  def help_test(conn, _params) do
    json(conn, "ok")
  end

  @instance Application.get_env(:pleroma, :instance)
  def config(conn, _params) do
    case get_format(conn) do
      "xml" ->
        response = """
        <config>
          <site>
            <name>#{Keyword.get(@instance, :name)}</name>
            <site>#{Web.base_url}</site>
            <textlimit>#{Keyword.get(@instance, :limit)}</textlimit>
            <closed>#{!Keyword.get(@instance, :registrations_open)}</closed>
          </site>
        </config>
        """
        conn
        |> put_resp_content_type("application/xml")
        |> send_resp(200, response)
      _ ->
        json(conn, %{
              site: %{
                name: Keyword.get(@instance, :name),
                server: Web.base_url,
                textlimit: Keyword.get(@instance, :limit),
                closed: if(Keyword.get(@instance, :registrations_open), do: "0", else: "1")
              }
             })
    end
  end

  def version(conn, _params) do
    version = Keyword.get(@instance, :version)
    case get_format(conn) do
      "xml" ->
        response = "<version>#{version}</version>"
        conn
        |> put_resp_content_type("application/xml")
        |> send_resp(200, response)
      _ -> json(conn, version)
    end
  end

  def emoji(conn, _params) do
    json conn, Enum.into(Formatter.get_custom_emoji(), %{})
  end

  def follow_import(%{assigns: %{user: user}} = conn, %{"list" => list}) do
    errors = list
    |> String.split()
    |> Enum.map(fn nick ->
      with %User{} = follower <- User.get_cached_by_ap_id(user.ap_id),
      %User{} = followed <- User.get_or_fetch_by_nickname(nick),
      {:ok, follower} <- User.follow(follower, followed),
      {:ok, _activity} <- ActivityPub.follow(follower, followed) do
        :ok
      else
        _e -> nick
      end
    end)
    |> Enum.reject(fn x -> x == :ok end)

    json conn, %{"failed follows" => errors}
  end
end
