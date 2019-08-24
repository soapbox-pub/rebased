defmodule Pleroma.Web.Mailer.SubscriptionController do
  use Pleroma.Web, :controller

  alias Pleroma.JWT
  alias Pleroma.Repo
  alias Pleroma.User

  def unsubscribe(conn, %{"token" => encoded_token}) do
    with {:ok, token} <- Base.decode64(encoded_token),
         {:ok, claims} <- JWT.verify_and_validate(token),
         %{"act" => %{"unsubscribe" => type}, "sub" => uid} <- claims,
         %User{} = user <- Repo.get(User, uid),
         {:ok, _user} <- User.switch_email_notifications(user, type, false) do
      render(conn, "unsubscribe_success.html", email: user.email)
    else
      _err ->
        render(conn, "unsubscribe_failure.html")
    end
  end
end
