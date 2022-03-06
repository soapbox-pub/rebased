# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateFilters do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:filters) do
      add(:user_id, references(:users, on_delete: :delete_all))
      add(:filter_id, :integer)
      add(:hide, :boolean)
      add(:phrase, :string)
      add(:context, {:array, :string})
      add(:expires_at, :utc_datetime)
      add(:whole_word, :boolean)

      timestamps()
    end

    create_if_not_exists(index(:filters, [:user_id]))

    create_if_not_exists(
      index(:filters, [:phrase], where: "hide = true", name: :hided_phrases_index)
    )
  end
end
