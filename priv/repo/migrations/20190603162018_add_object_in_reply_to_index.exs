# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddObjectInReplyToIndex do
  use Ecto.Migration

  def change do
    create(index(:objects, ["(data->>'inReplyTo')"], name: :objects_in_reply_to_index))
  end
end
