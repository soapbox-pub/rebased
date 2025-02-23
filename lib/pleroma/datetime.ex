defmodule Pleroma.DateTime do
  @callback utc_now() :: NaiveDateTime.t()
end
