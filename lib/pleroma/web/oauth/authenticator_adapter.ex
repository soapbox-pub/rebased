defmodule Pleroma.Web.AuthenticatorAdapter do
  alias Pleroma.User

  @callback get_user(Plug.Conn.t()) :: {:ok, User.t()} | {:error, any()}

  @callback handle_error(Plug.Conn.t(), any()) :: any()
end
