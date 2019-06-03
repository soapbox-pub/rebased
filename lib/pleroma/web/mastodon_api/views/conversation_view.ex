defmodule Pleroma.Web.MastodonAPI.ConversationView do
  use Pleroma.Web, :view

  alias Pleroma.Activity
  alias Pleroma.Repo
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.MastodonAPI.StatusView

  def render("participation.json", %{participation: participation, user: user}) do
    participation = Repo.preload(participation, conversation: :users)

    last_activity_id =
      with nil <- participation.last_activity_id do
        ActivityPub.fetch_latest_activity_id_for_context(participation.conversation.ap_id, %{
          "user" => user,
          "blocking_user" => user
        })
      end

    activity = Activity.get_by_id_with_object(last_activity_id)

    last_status = StatusView.render("status.json", %{activity: activity, for: user})

    # Conversations return all users except the current user.
    users =
      participation.conversation.users
      |> Enum.reject(&(&1.id == user.id))

    accounts =
      AccountView.render("accounts.json", %{
        users: users,
        as: :user
      })

    %{
      id: participation.id |> to_string(),
      accounts: accounts,
      unread: !participation.read,
      last_status: last_status
    }
  end
end
