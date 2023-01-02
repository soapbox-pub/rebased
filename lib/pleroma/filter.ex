# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Filter do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.Repo
  alias Pleroma.User

  @type t() :: %__MODULE__{}
  @type format() :: :postgres | :re

  schema "filters" do
    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)
    field(:filter_id, :integer)
    field(:hide, :boolean, default: false)
    field(:whole_word, :boolean, default: true)
    field(:phrase, :string)
    field(:context, {:array, :string})
    field(:expires_at, :naive_datetime)

    timestamps()
  end

  @spec get(integer() | String.t(), User.t()) :: t() | nil
  def get(id, %{id: user_id} = _user) do
    query =
      from(
        f in __MODULE__,
        where: f.filter_id == ^id,
        where: f.user_id == ^user_id
      )

    Repo.one(query)
  end

  @spec get_active(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def get_active(query) do
    from(f in query, where: is_nil(f.expires_at) or f.expires_at > ^NaiveDateTime.utc_now())
  end

  @spec get_irreversible(Ecto.Query.t()) :: Ecto.Query.t()
  def get_irreversible(query) do
    from(f in query, where: f.hide)
  end

  @spec get_filters(Ecto.Query.t() | module(), User.t()) :: [t()]
  def get_filters(query \\ __MODULE__, %User{id: user_id}) do
    query =
      from(
        f in query,
        where: f.user_id == ^user_id,
        order_by: [desc: :id]
      )

    Repo.all(query)
  end

  @spec create(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(attrs \\ %{}) do
    Repo.transaction(fn -> create_with_expiration(attrs) end)
  end

  defp create_with_expiration(attrs) do
    with {:ok, filter} <- do_create(attrs),
         {:ok, _} <- maybe_add_expiration_job(filter) do
      filter
    else
      {:error, error} -> Repo.rollback(error)
    end
  end

  defp do_create(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:phrase, :context, :hide, :expires_at, :whole_word, :user_id, :filter_id])
    |> maybe_add_filter_id()
    |> validate_required([:phrase, :context, :user_id, :filter_id])
    |> maybe_add_expires_at(attrs)
    |> Repo.insert()
  end

  defp maybe_add_filter_id(%{changes: %{filter_id: _}} = changeset), do: changeset

  defp maybe_add_filter_id(%{changes: %{user_id: user_id}} = changeset) do
    # If filter_id wasn't given, use the max filter_id for this user plus 1.
    # XXX This could result in a race condition if a user tries to add two
    # different filters for their account from two different clients at the
    # same time, but that should be unlikely.

    max_id_query =
      from(
        f in __MODULE__,
        where: f.user_id == ^user_id,
        select: max(f.filter_id)
      )

    filter_id =
      case Repo.one(max_id_query) do
        # Start allocating from 1
        nil ->
          1

        max_id ->
          max_id + 1
      end

    change(changeset, filter_id: filter_id)
  end

  # don't override expires_at, if passed expires_at and expires_in
  defp maybe_add_expires_at(%{changes: %{expires_at: %NaiveDateTime{} = _}} = changeset, _) do
    changeset
  end

  defp maybe_add_expires_at(changeset, %{expires_in: expires_in})
       when is_integer(expires_in) and expires_in > 0 do
    expires_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(expires_in)
      |> NaiveDateTime.truncate(:second)

    change(changeset, expires_at: expires_at)
  end

  defp maybe_add_expires_at(changeset, %{expires_in: nil}) do
    change(changeset, expires_at: nil)
  end

  defp maybe_add_expires_at(changeset, _), do: changeset

  defp maybe_add_expiration_job(%{expires_at: %NaiveDateTime{} = expires_at} = filter) do
    Pleroma.Workers.PurgeExpiredFilter.enqueue(%{
      filter_id: filter.id,
      expires_at: DateTime.from_naive!(expires_at, "Etc/UTC")
    })
  end

  defp maybe_add_expiration_job(_), do: {:ok, nil}

  @spec delete(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def delete(%__MODULE__{} = filter) do
    Repo.transaction(fn -> delete_with_expiration(filter) end)
  end

  defp delete_with_expiration(filter) do
    with {:ok, _} <- maybe_delete_old_expiration_job(filter, nil),
         {:ok, filter} <- Repo.delete(filter) do
      filter
    else
      {:error, error} -> Repo.rollback(error)
    end
  end

  @spec update(t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def update(%__MODULE__{} = filter, params) do
    Repo.transaction(fn -> update_with_expiration(filter, params) end)
  end

  defp update_with_expiration(filter, params) do
    with {:ok, updated} <- do_update(filter, params),
         {:ok, _} <- maybe_delete_old_expiration_job(filter, updated),
         {:ok, _} <-
           maybe_add_expiration_job(updated) do
      updated
    else
      {:error, error} -> Repo.rollback(error)
    end
  end

  defp do_update(filter, params) do
    filter
    |> cast(params, [:phrase, :context, :hide, :expires_at, :whole_word])
    |> validate_required([:phrase, :context])
    |> maybe_add_expires_at(params)
    |> Repo.update()
  end

  defp maybe_delete_old_expiration_job(%{expires_at: nil}, _), do: {:ok, nil}

  defp maybe_delete_old_expiration_job(%{expires_at: expires_at}, %{expires_at: expires_at}) do
    {:ok, nil}
  end

  defp maybe_delete_old_expiration_job(%{id: id}, _) do
    with %Oban.Job{} = job <- Pleroma.Workers.PurgeExpiredFilter.get_expiration(id) do
      Repo.delete(job)
    else
      nil -> {:ok, nil}
    end
  end

  @spec compose_regex(User.t() | [t()], format()) :: String.t() | Regex.t() | nil
  def compose_regex(user_or_filters, format \\ :postgres)

  def compose_regex(%User{} = user, format) do
    __MODULE__
    |> get_active()
    |> get_irreversible()
    |> get_filters(user)
    |> compose_regex(format)
  end

  def compose_regex([_ | _] = filters, format) do
    phrases =
      filters
      |> Enum.map(& &1.phrase)
      |> Enum.join("|")

    case format do
      :postgres ->
        "\\y(#{phrases})\\y"

      :re ->
        ~r/\b#{phrases}\b/i

      _ ->
        nil
    end
  end

  def compose_regex(_, _), do: nil
end
