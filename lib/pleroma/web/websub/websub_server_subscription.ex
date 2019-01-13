# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

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
