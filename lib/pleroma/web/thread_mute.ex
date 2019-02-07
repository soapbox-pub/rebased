# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ThreadMute do
  use Ecto.Schema

  alias Pleroma.{Activity, Notification, User}

  schema "thread_mutes" do
    belongs_to(:user, User, type: Pleroma.FlakeId)
    field(:context, :string)
  end

  def add_mute(user, id) do
    user_id = user.id
    %{data: %{"context" => context}} = Activity.get_by_id(id)
    Pleroma.Repo.insert(%Pleroma.Web.ThreadMute{}, %{user: user_id, context: context})
  end

  def remove_mute(user, id) do
  end

  def mute_thread() do
  end
end
