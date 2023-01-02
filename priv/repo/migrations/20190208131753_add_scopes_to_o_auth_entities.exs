# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddScopeSToOAuthEntities do
  use Ecto.Migration

  def change do
    for t <- [:oauth_authorizations, :oauth_tokens] do
      alter table(t) do
        add(:scopes, {:array, :string}, default: [], null: false)
      end
    end
  end
end
