defmodule Mix.Tasks.GeneratePasswordReset do
  use Mix.Task
  alias Pleroma.User

  @moduledoc """
  Generate password reset link for user

  Usage: ``mix generate_password_reset <nickname>``

  Example: ``mix generate_password_reset lain``
  """
  def run([nickname]) do
    Mix.Task.run("app.start")

    with %User{local: true} = user <- User.get_by_nickname(nickname),
         {:ok, token} <- Pleroma.PasswordResetToken.create_token(user) do
      IO.puts("Generated password reset token for #{user.nickname}")

      IO.puts(
        "Url: #{
          Pleroma.Web.Router.Helpers.util_url(
            Pleroma.Web.Endpoint,
            :show_password_reset,
            token.token
          )
        }"
      )
    else
      _ ->
        IO.puts("No local user #{nickname}")
    end
  end
end
