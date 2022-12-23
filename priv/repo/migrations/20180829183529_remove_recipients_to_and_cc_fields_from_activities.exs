# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RemoveRecipientsToAndCcFieldsFromActivities do
  use Ecto.Migration

  def up do
    alter table(:activities) do
      remove(:recipients_to)
      remove(:recipients_cc)
    end
  end

  def down do
    alter table(:activities) do
      add(:recipients_to, {:array, :string})
      add(:recipients_cc, {:array, :string})
    end
  end
end
