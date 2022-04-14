# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateReportNotes do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:report_notes) do
      add(:user_id, references(:users, type: :uuid))
      add(:activity_id, references(:activities, type: :uuid))
      add(:content, :string)

      timestamps()
    end
  end
end
