defmodule Pleroma.Notification do
  use Ecto.Schema
  alias Pleroma.{User, Activity, Notification, Repo}
  import Ecto.Query

  schema "notifications" do
    field :seen, :boolean, default: false
    belongs_to :user, Pleroma.User
    belongs_to :activity, Pleroma.Activity

    timestamps()
  end

  def for_user(user, opts \\ %{}) do
    query = from n in Notification,
      where: n.user_id == ^user.id,
      order_by: [desc: n.id],
      preload: [:activity],
      limit: 20
    Repo.all(query)
  end

  def create_notifications(%Activity{id: id, data: %{"to" => to, "type" => type}} = activity) when type in ["Create"] do
    users = User.get_notified_from_activity(activity)

    notifications = Enum.map(users, fn (user) -> create_notification(activity, user) end)
    {:ok, notifications}
  end
  def create_notifications(_), do: {:ok, []}

  # TODO move to sql, too.
  def create_notification(%Activity{} = activity, %User{} = user) do
    notification = %Notification{user_id: user.id, activity_id: activity.id}
    {:ok, notification} = Repo.insert(notification)
    notification
  end
end

