defmodule Pleroma.Web.Websub.WebsubClientSubscription do
  use Ecto.Schema

  schema "websub_client_subscriptions" do
    field :topic, :string
    field :secret, :string
    field :valid_until, :naive_datetime
    field :state, :string
    field :subscribers, {:array, :string}, default: []

    timestamps()
  end
end
