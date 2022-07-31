# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateUserInviteTokens do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:user_invite_tokens) do
      add(:token, :string)
      add(:used, :boolean, default: false)

      timestamps()
    end
  end
end
