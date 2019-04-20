defmodule Pleroma.JWT do
  use Joken.Config

  @impl true
  def token_config do
    default_claims(skip: [:aud])
    |> add_claim("aud", &Pleroma.Web.Endpoint.url/0, &(&1 == Pleroma.Web.Endpoint.url()))
  end
end
