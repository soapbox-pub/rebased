defmodule Pleroma.Web.Websub.WebsubServerSubscription do
  use Ecto.Schema

  schema "websub_server_subscriptions" do
    field(:topic, :string)
    field(:callback, :string)
    field(:secret, :string)
    field(:valid_until, :naive_datetime)
    field(:state, :string)

    timestamps()
  end
end
