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
