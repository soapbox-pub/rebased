# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddQuoteUrlIndexToObjects do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:objects, ["(data->'quoteUrl')"], name: :objects_quote_url))
  end
end
