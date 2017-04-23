defmodule Pleroma.Web.OStatus.FeedRepresenter do
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.OStatus.{UserRepresenter, ActivityRepresenter}

  def to_simple_form(user, activities, users) do
    most_recent_update = (List.first(activities) || user).updated_at
    |> NaiveDateTime.to_iso8601

    h = fn(str) -> [to_charlist(str)] end

    entries = Enum.map(activities, fn(activity) ->
      {:entry, ActivityRepresenter.to_simple_form(activity, user)}
    end)
    |> Enum.filter(fn ({_, form}) -> form end)

    [{
      :feed, [
        xmlns: 'http://www.w3.org/2005/Atom',
        "xmlns:activity": 'http://activitystrea.ms/spec/1.0/',
        "xmlns:poco": 'http://portablecontacts.net/spec/1.0'
      ], [
        {:id, h.(OStatus.feed_path(user))},
        {:title, ['#{user.nickname}\'s timeline']},
        {:updated, h.(most_recent_update)},
        {:link, [rel: 'hub', href: h.(OStatus.pubsub_path(user))], []},
        {:link, [rel: 'self', href: h.(OStatus.feed_path(user))], []},
        {:author, UserRepresenter.to_simple_form(user)},
      ] ++ entries
    }]
  end
end
