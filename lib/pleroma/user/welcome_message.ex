defmodule Pleroma.User.WelcomeMessage do
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  import Ecto.Query

  def post_welcome_message_to_user(user) do
    with %User{} = sender_user <- welcome_user(),
         message when is_binary(message) <- welcome_message() do
      CommonAPI.post(sender_user, %{
        "visibility" => "direct",
        "status" => "@#{user.nickname}\n#{message}"
      })
    else
      _ -> {:ok, nil}
    end
  end

  defp welcome_user() do
    if nickname = Pleroma.Config.get([:instance, :welcome_user_nickname]) do
      from(u in User,
        where: u.local == true,
        where: u.nickname == ^nickname
      )
      |> Pleroma.Repo.one()
    else
      nil
    end
  end

  defp welcome_message() do
    Pleroma.Config.get([:instance, :welcome_message])
  end
end
