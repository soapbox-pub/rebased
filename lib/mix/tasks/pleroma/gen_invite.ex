defmodule Mix.Tasks.Pleroma.Gen.Invite do
  use Mix.Task

  @shortdoc "Generates a user invite token"
  def run([]) do
    Mix.Task.run("app.start")

    with {:ok, token} <- Pleroma.UserInviteToken.create_token() do
      Mix.shell().info("Generated user invite token")

      url =
        Pleroma.Web.Router.Helpers.redirect_url(
          Pleroma.Web.Endpoint,
          :registration_page,
          token.token
        )

      IO.puts("URL: #{url}")
    else
      _ ->
        Mix.shell().error("Could not create invite token.")
    end
  end
end
