defmodule Pleroma.Web.Websub.WebsubClientSubscription do
  use Ecto.Schema
  alias Pleroma.User

  schema "websub_client_subscriptions" do
    field :topic, :string
    field :secret, :string
    field :valid_until, :naive_datetime
    field :state, :string
    field :subscribers, {:array, :string}, default: []
    field :hub, :string
    belongs_to :user, User

    timestamps()
  end
end
