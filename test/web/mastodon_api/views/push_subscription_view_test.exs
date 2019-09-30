# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.PushSubscriptionViewTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Web.MastodonAPI.PushSubscriptionView, as: View
  alias Pleroma.Web.Push

  test "Represent a subscription" do
    subscription = insert(:push_subscription, data: %{"alerts" => %{"mention" => true}})

    expected = %{
      alerts: %{"mention" => true},
      endpoint: subscription.endpoint,
      id: to_string(subscription.id),
      server_key: Keyword.get(Push.vapid_config(), :public_key)
    }

    assert expected == View.render("push_subscription.json", %{subscription: subscription})
  end
end
