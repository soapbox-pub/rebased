defmodule Pleroma.Web.TwitterAPI.UtilController do
  use Pleroma.Web, :controller
  require Logger
  alias Pleroma.Web
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.WebFinger
  alias Pleroma.Web.CommonAPI
  alias Comeonin.Pbkdf2
  alias Pleroma.Formatter
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.{Repo, PasswordResetToken, User}

  def show_password_reset(conn, %{"token" => token}) do
    with %{used: false} = token <- Repo.get_by(PasswordResetToken, %{token: token}),
         %User{} = user <- Repo.get(User, token.user_id) do
      render(conn, "password_reset.html", %{
        token: token,
        user: user
      })
    else
      _e -> render(conn, "invalid_token.html")
    end
  end

  def password_reset(conn, %{"data" => data}) do
    with {:ok, _} <- PasswordResetToken.reset_password(data["token"], data) do
      render(conn, "password_reset_success.html")
    else
      _e -> render(conn, "password_reset_failed.html")
    end
  end

  def help_test(conn, _params) do
    json(conn, "ok")
  end

  def remote_subscribe(conn, %{"nickname" => nick, "profile" => _}) do
    with %User{} = user <- User.get_cached_by_nickname(nick), avatar = User.avatar_url(user) do
      conn
      |> render("subscribe.html", %{nickname: nick, avatar: avatar, error: false})
    else
      _e ->
        render(conn, "subscribe.html", %{
          nickname: nick,
          avatar: nil,
          error: "Could not find user"
        })
    end
  end

  def remote_subscribe(conn, %{"user" => %{"nickname" => nick, "profile" => profile}}) do
    with {:ok, %{"subscribe_address" => template}} <- WebFinger.finger(profile),
         %User{ap_id: ap_id} <- User.get_cached_by_nickname(nick) do
      conn
      |> Phoenix.Controller.redirect(external: String.replace(template, "{uri}", ap_id))
    else
      _e ->
        render(conn, "subscribe.html", %{
          nickname: nick,
          avatar: nil,
          error: "Something went wrong."
        })
    end
  end

  def remote_follow(%{assigns: %{user: user}} = conn, %{"acct" => acct}) do
    {err, followee} = OStatus.find_or_make_user(acct)
    avatar = User.avatar_url(followee)
    name = followee.nickname
    id = followee.id

    if !!user do
      conn
      |> render("follow.html", %{error: err, acct: acct, avatar: avatar, name: name, id: id})
    else
      conn
      |> render("follow_login.html", %{
        error: false,
        acct: acct,
        avatar: avatar,
        name: name,
        id: id
      })
    end
  end

  def do_remote_follow(conn, %{
        "authorization" => %{"name" => username, "password" => password, "id" => id}
      }) do
    followee = Repo.get(User, id)
    avatar = User.avatar_url(followee)
    name = followee.nickname

    with %User{} = user <- User.get_cached_by_nickname(username),
         true <- Pbkdf2.checkpw(password, user.password_hash),
         %User{} = _followed <- Repo.get(User, id),
         {:ok, follower} <- User.follow(user, followee),
         {:ok, _activity} <- ActivityPub.follow(follower, followee) do
      conn
      |> render("followed.html", %{error: false})
    else
      _e ->
        conn
        |> render("follow_login.html", %{
          error: "Wrong username or password",
          id: id,
          name: name,
          avatar: avatar
        })
    end
  end

  def do_remote_follow(%{assigns: %{user: user}} = conn, %{"user" => %{"id" => id}}) do
    with %User{} = followee <- Repo.get(User, id),
         {:ok, follower} <- User.follow(user, followee),
         {:ok, _activity} <- ActivityPub.follow(follower, followee) do
      conn
      |> render("followed.html", %{error: false})
    else
      e ->
        Logger.debug("Remote follow failed with error #{inspect(e)}")

        conn
        |> render("followed.html", %{error: inspect(e)})
    end
  end

  @instance Application.get_env(:pleroma, :instance)
  def config(conn, _params) do
    case get_format(conn) do
      "xml" ->
        response = """
        <config>
          <site>
            <name>#{Keyword.get(@instance, :name)}</name>
            <site>#{Web.base_url()}</site>
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
            server: Web.base_url(),
            textlimit: to_string(Keyword.get(@instance, :limit)),
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

      _ ->
        json(conn, version)
    end
  end

  def emoji(conn, _params) do
    json(conn, Enum.into(Formatter.get_custom_emoji(), %{}))
  end

  def follow_import(conn, %{"list" => %Plug.Upload{} = listfile}) do
    follow_import(conn, %{"list" => File.read!(listfile.path)})
  end

  def follow_import(%{assigns: %{user: user}} = conn, %{"list" => list}) do
    Task.start(fn ->
      String.split(list)
      |> Enum.map(fn account ->
        with %User{} = follower <- User.get_cached_by_ap_id(user.ap_id),
             %User{} = followed <- User.get_or_fetch(account),
             {:ok, follower} <- User.follow(follower, followed) do
          ActivityPub.follow(follower, followed)
        else
          _e -> Logger.debug("follow_import: following #{account} failed")
        end
      end)
    end)

    json(conn, "job started")
  end

  def change_password(%{assigns: %{user: user}} = conn, params) do
    case CommonAPI.Utils.confirm_current_password(user, params["password"]) do
      {:ok, user} ->
        with {:ok, _user} <-
               User.reset_password(user, %{
                 password: params["new_password"],
                 password_confirmation: params["new_password_confirmation"]
               }) do
          json(conn, %{status: "success"})
        else
          {:error, changeset} ->
            {_, {error, _}} = Enum.at(changeset.errors, 0)
            json(conn, %{error: "New password #{error}."})

          _ ->
            json(conn, %{error: "Unable to change password."})
        end

      {:error, msg} ->
        json(conn, %{error: msg})
    end
  end

  def delete_account(%{assigns: %{user: user}} = conn, params) do
    case CommonAPI.Utils.confirm_current_password(user, params["password"]) do
      {:ok, user} ->
        Task.start(fn -> User.delete(user) end)
        json(conn, %{status: "success"})

      {:error, msg} ->
        json(conn, %{error: msg})
    end
  end
end
