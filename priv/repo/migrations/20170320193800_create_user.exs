# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreatePleroma.User do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:users) do
      add(:email, :string)
      add(:password_hash, :string)
      add(:name, :string)
      add(:nickname, :string)
      add(:bio, :string)

      timestamps()
    end
  end
end
