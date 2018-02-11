defmodule Pleroma.Web.OAuth.FallbackController do
    use Pleroma.Web, :controller
    alias Pleroma.Web.OAuth.OAuthController

    # No user/password
    def call(conn, _) do
        conn
        |> put_flash(:error, "Invalid Username/Password")
        |> OAuthController.authorize(conn.params)
    end

end