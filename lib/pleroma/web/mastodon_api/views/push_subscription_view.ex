defmodule Pleroma.Web.MastodonAPI.PushSubscriptionView do
  use Pleroma.Web, :view

  def render("push_subscription.json", %{subscription: subscription}) do
    %{
      id: to_string(subscription.id),
      endpoint: subscription.endpoint,
      alerts: Map.get(subscription.data, "alerts"),
      server_key: server_key()
    }
  end

  defp server_key do
    Keyword.get(Application.get_env(:web_push_encryption, :vapid_details), :public_key)
  end
end
