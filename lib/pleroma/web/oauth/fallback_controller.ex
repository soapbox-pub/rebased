defmodule Pleroma.Web.OAuth.FallbackController do
    use Pleroma.Web, :controller
    alias Pleroma.Web.OAuth.OAuthController

    # No user
    def call(conn, nil) do
        conn
        |> put_flash(:error, "Invalid Username/Password")
        |> OAuthController.authorize(conn.params)
    end

    # No password
    def call(conn, false) do
        conn
        |> put_flash(:error, "Invalid Username/Password")
        |> OAuthController.authorize(conn.params)
    end

end