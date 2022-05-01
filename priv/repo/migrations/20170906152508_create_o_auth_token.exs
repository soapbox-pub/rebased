# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.CreateOAuthToken do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:oauth_tokens) do
      add(:app_id, references(:apps))
      add(:user_id, references(:users))
      add(:token, :string)
      add(:refresh_token, :string)
      add(:valid_until, :naive_datetime_usec)

      timestamps()
    end
  end
end
