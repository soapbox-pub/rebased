defmodule Mix.Tasks.GenerateInviteToken do
  use Mix.Task

  @shortdoc "Generate password reset link for user"
  def run([]) do
    Mix.Task.run("app.start")

    with {:ok, token} <- Pleroma.UserInviteToken.create_token() do
      IO.puts("Generated user invite token")

      IO.puts(
        "Url: #{
          Pleroma.Web.Router.Helpers.redirect_url(
            Pleroma.Web.Endpoint,
            :registration_page,
            token.token
          )
        }"
      )
    else
      _ ->
        IO.puts("Error creating token")
    end
  end
end
