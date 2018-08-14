defmodule Pleroma.Filter do
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Pleroma.{User, Repo, Activity}

  schema "filters" do
    belongs_to(:user, Pleroma.User)
    field(:filter_id, :integer)
    field(:hide, :boolean, default: false)
    field(:whole_word, :boolean, default: true)
    field(:phrase, :string)
    field(:context, {:array, :string})
    field(:expires_at, :utc_datetime)

    timestamps()
  end

  def get(id, %{id: user_id} = _user) do
    query =
      from(
        f in Pleroma.Filter,
        where: f.filter_id == ^id,
        where: f.user_id == ^user_id
      )

    Repo.one(query)
  end

  def get_filters(%Pleroma.User{id: user_id} = user) do
    query =
      from(
        f in Pleroma.Filter,
        where: f.user_id == ^user_id
      )

    Repo.all(query)
  end

  def create(%Pleroma.Filter{} = filter) do
    Repo.insert(filter)
  end

  def delete(%Pleroma.Filter{id: filter_key} = filter) when is_number(filter_key) do
    Repo.delete(filter)
  end

  def delete(%Pleroma.Filter{id: filter_key} = filter) when is_nil(filter_key) do
    %Pleroma.Filter{id: id} = get(filter.filter_id, %{id: filter.user_id})

    filter
    |> Map.put(:id, id)
    |> Repo.delete()
  end

  def update(%Pleroma.Filter{} = filter) do
    destination = Map.from_struct(filter)

    Pleroma.Filter.get(filter.filter_id, %{id: filter.user_id})
    |> cast(destination, [:phrase, :context, :hide, :expires_at, :whole_word])
    |> Repo.update()
  end
end
