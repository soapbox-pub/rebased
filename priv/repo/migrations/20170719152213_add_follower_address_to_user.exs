defmodule Pleroma.Repo.Migrations.AddFollowerAddressToUser do
  use Ecto.Migration
  import Ecto.Query
  import Supervisor.Spec
  alias Pleroma.{Repo, User}

  def up do
    alter table(:users) do
      add :follower_address, :string, unique: true
    end

    # Not needed anymore for new setups.
    # flush()

    # children = [
    #   # Start the endpoint when the application starts
    #   supervisor(Pleroma.Web.Endpoint, [])
    # ]
    # opts = [strategy: :one_for_one, name: Pleroma.Supervisor]
    # Supervisor.start_link(children, opts)

    # Enum.each(Repo.all(User), fn (user) ->
    #   if !user.follower_address do
    #     cs = Ecto.Changeset.change(user, %{follower_address: User.ap_followers(user)})
    #     Repo.update!(cs)
    #   end
    # end)
  end

  def down do
    alter table(:users) do
      remove :follower_address
    end
  end
end
