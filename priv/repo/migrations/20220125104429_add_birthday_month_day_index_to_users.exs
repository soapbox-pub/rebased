# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddBirthdayMonthDayIndexToUsers do
  use Ecto.Migration

  def change do
    create(
      index(:users, ["date_part('month', birthday)", "date_part('day', birthday)"],
        name: :users_birthday_month_day_index
      )
    )
  end
end
