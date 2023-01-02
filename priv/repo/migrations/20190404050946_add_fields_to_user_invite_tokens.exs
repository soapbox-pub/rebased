# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddFieldsToUserInviteTokens do
  use Ecto.Migration

  def change do
    alter table(:user_invite_tokens) do
      add(:expires_at, :date)
      add(:uses, :integer, default: 0)
      add(:max_use, :integer)
      add(:invite_type, :string, default: "one_time")
    end
  end
end
