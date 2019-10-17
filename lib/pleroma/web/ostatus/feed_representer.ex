# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OStatus.FeedRepresenter do
  alias Pleroma.User
  alias Pleroma.Web.MediaProxy
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.OStatus.ActivityRepresenter
  alias Pleroma.Web.OStatus.UserRepresenter

  def to_simple_form(user, activities, _users) do
    most_recent_update =
      (List.first(activities) || user).updated_at
      |> NaiveDateTime.to_iso8601()

    h = fn str -> [to_charlist(str)] end

    last_activity = List.last(activities)

    entries =
      activities
      |> Enum.map(fn activity ->
        {:entry, ActivityRepresenter.to_simple_form(activity, user)}
      end)
      |> Enum.filter(fn {_, form} -> form end)

    [
      {
        :feed,
        [
          xmlns: 'http://www.w3.org/2005/Atom',
          "xmlns:thr": 'http://purl.org/syndication/thread/1.0',
          "xmlns:activity": 'http://activitystrea.ms/spec/1.0/',
          "xmlns:poco": 'http://portablecontacts.net/spec/1.0',
          "xmlns:ostatus": 'http://ostatus.org/schema/1.0'
        ],
        [
          {:id, h.(OStatus.feed_path(user))},
          {:title, ['#{user.nickname}\'s timeline']},
          {:updated, h.(most_recent_update)},
          {:logo, [to_charlist(User.avatar_url(user) |> MediaProxy.url())]},
          {:link, [rel: 'self', href: h.(OStatus.feed_path(user)), type: 'application/atom+xml'],
           []},
          {:author, UserRepresenter.to_simple_form(user)}
        ] ++
          if last_activity do
            [
              {:link,
               [
                 rel: 'next',
                 href:
                   to_charlist(OStatus.feed_path(user)) ++
                     '?max_id=' ++ to_charlist(last_activity.id),
                 type: 'application/atom+xml'
               ], []}
            ]
          else
            []
          end ++ entries
      }
    ]
  end
end
