defmodule Pleroma.Repo.Migrations.AddFeaturedAddressToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add(:featured_address, :string)
    end

    create(index(:users, [:featured_address]))

    execute("""

    update users set featured_address = concat(ap_id, '/collections/featured') where local = true and featured_address is null;

    """)
  end

  def down do
    alter table(:users) do
      remove(:featured_address)
    end
  end
end
