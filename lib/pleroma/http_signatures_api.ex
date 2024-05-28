defmodule Pleroma.HTTPSignaturesAPI do
  @callback validate_conn(conn :: Plug.Conn.t()) :: boolean
  @callback signature_for_conn(conn :: Plug.Conn.t()) :: map
end
