# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Websub.WebsubClientSubscription do
  use Ecto.Schema
  alias Pleroma.User

  schema "websub_client_subscriptions" do
    field(:topic, :string)
    field(:secret, :string)
    field(:valid_until, :naive_datetime_usec)
    field(:state, :string)
    field(:subscribers, {:array, :string}, default: [])
    field(:hub, :string)
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)

    timestamps()
  end
end
