# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddRecipientsToActivities do
  use Ecto.Migration

  def change do
    alter table(:activities) do
      add(:recipients, {:array, :string})
    end

    create_if_not_exists(index(:activities, [:recipients], using: :gin))
  end
end
