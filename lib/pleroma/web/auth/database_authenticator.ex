defmodule Pleroma.Web.Auth.DatabaseAuthenticator do
  alias Pleroma.User

  @implementation Pleroma.Config.get(
                    Pleroma.Web.Auth.DatabaseAuthenticator,
                    Pleroma.Web.Auth.PleromaDatabaseAuthenticator
                  )

  @callback get_user(Plug.Conn.t()) :: {:ok, User.t()} | {:error, any()}
  defdelegate get_user(plug), to: @implementation

  @callback handle_error(Plug.Conn.t(), any()) :: any()
  defdelegate handle_error(plug, error), to: @implementation
end
