# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.UsersAddPublicKey do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add_if_not_exists(:public_key, :text)
    end

    execute("UPDATE users SET public_key = source_data->'publicKey'->>'publicKeyPem'")
  end

  def down do
    alter table(:users) do
      remove_if_exists(:public_key, :text)
    end
  end
end
