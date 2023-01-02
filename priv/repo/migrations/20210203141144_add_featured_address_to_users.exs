# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddFeaturedAddressToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add(:featured_address, :string)
    end

    create(index(:users, [:featured_address]))

    execute("""

    update users set featured_address = concat(ap_id, '/collections/featured') where local = true and featured_address is null;

    """)
  end

  def down do
    alter table(:users) do
      remove(:featured_address)
    end
  end
end
