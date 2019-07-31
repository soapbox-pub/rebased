# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OStatus.FollowHandler do
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.OStatus
  alias Pleroma.Web.XML

  def handle(entry, doc) do
    with {:ok, actor} <- OStatus.find_make_or_update_actor(doc),
         id when not is_nil(id) <- XML.string_from_xpath("/entry/id", entry),
         followed_uri when not is_nil(followed_uri) <-
           XML.string_from_xpath("/entry/activity:object/id", entry),
         {:ok, followed} <- OStatus.find_or_make_user(followed_uri),
         {:ok, activity} <- ActivityPub.follow(actor, followed, id, false) do
      User.follow(actor, followed)
      {:ok, activity}
    end
  end
end
