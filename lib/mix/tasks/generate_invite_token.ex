defmodule Mix.Tasks.GenerateInviteToken do
  use Mix.Task

  @moduledoc """
  Generates invite token

  This is in the form of a URL to be used by the Invited user to register themselves.

  ## Usage
  ``mix generate_invite_token``
  """
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
