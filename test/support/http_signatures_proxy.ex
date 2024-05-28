defmodule Pleroma.Test.HTTPSignaturesProxy do
  @behaviour Pleroma.HTTPSignaturesAPI

  @impl true
  defdelegate validate_conn(conn), to: HTTPSignatures

  @impl true
  defdelegate signature_for_conn(conn), to: HTTPSignatures
end
