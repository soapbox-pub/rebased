defmodule Pleroma.Web.MastodonAPI.PushSubscriptionView do
  use Pleroma.Web, :view
  alias Pleroma.Web.MastodonAPI.PushSubscriptionView

  def render("push_subscription.json", %{subscription: subscription}) do
    %{
      id: to_string(subscription.id),
      endpoint: subscription.endpoint,
      alerts: Map.get(subscription.data, "alerts")
    }
  end
end
