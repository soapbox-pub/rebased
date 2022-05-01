# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddOauthTokenIndexes do
  use Ecto.Migration

  def change do
    create_if_not_exists(unique_index(:oauth_tokens, [:token]))
    create_if_not_exists(index(:oauth_tokens, [:app_id]))
    create_if_not_exists(index(:oauth_tokens, [:user_id]))
  end
end
