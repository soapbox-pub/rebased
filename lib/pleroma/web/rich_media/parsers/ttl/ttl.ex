defmodule Pleroma.Web.RichMedia.Parser.TTL do
  @callback ttl(Map.t(), String.t()) :: {:ok, Integer.t()} | {:error, String.t()}
end
