defmodule Pleroma.List do
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Pleroma.{User, Repo}

  schema "lists" do
    belongs_to(:user, Pleroma.User)
    field(:title, :string)
    field(:following, {:array, :string}, default: [])

    timestamps()
  end

  def title_changeset(list, attrs \\ %{}) do
    list
    |> cast(attrs, [:title])
    |> validate_required([:title])
  end

  def follow_changeset(list, attrs \\ %{}) do
    list
    |> cast(attrs, [:following])
    |> validate_required([:following])
  end

  def for_user(user, opts) do
    query =
      from(
        l in Pleroma.List,
        where: l.user_id == ^user.id,
        order_by: [desc: l.id],
        limit: 50
      )

    Repo.all(query)
  end

  def get(%{id: user_id} = _user, id) do
    query =
      from(
        l in Pleroma.List,
        where: l.id == ^id,
        where: l.user_id == ^user_id
      )

    Repo.one(query)
  end

  def get_following(%Pleroma.List{following: following} = list) do
    q = from(
      u in User,
      where: u.follower_address in ^following
    )
    {:ok, Repo.all(q)}
  end

  def rename(%Pleroma.List{} = list, title) do
    list
    |> title_changeset(%{title: title})
    |> Repo.update()
  end

  def create(title, %User{} = creator) do
    list = %Pleroma.List{user_id: creator.id, title: title}
    Repo.insert(list)
  end

  # TODO check that user is following followed
  def follow(%Pleroma.List{following: following} = list, %User{} = followed) do
    update_follows(list, %{following: Enum.uniq([followed.follower_address | following])})
  end

  def unfollow(%Pleroma.List{following: following} = list, %User{} = unfollowed) do
    update_follows(list, %{following: List.delete(following, unfollowed.follower_address)})
  end

  def delete(%Pleroma.List{} = list) do
    Repo.delete(list)
  end

  def update_follows(%Pleroma.List{} = list, attrs) do
    list
    |> follow_changeset(attrs)
    |> Repo.update()
  end
end
