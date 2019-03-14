defmodule Pleroma.Web.MastodonAPI.MastodonAPI do
  import Ecto.Query
  import Ecto.Changeset

  alias Pleroma.Repo
  alias Pleroma.User

  @default_limit 20

  def get_followers(user, params \\ %{}) do
    user
    |> User.get_followers_query()
    |> paginate(params)
    |> Repo.all()
  end

  def get_friends(user, params \\ %{}) do
    user
    |> User.get_friends_query()
    |> paginate(params)
    |> Repo.all()
  end

  def paginate(query, params \\ %{}) do
    options = cast_params(params)

    query
    |> restrict(:max_id, options)
    |> restrict(:since_id, options)
    |> restrict(:limit, options)
    |> order_by([u], fragment("? desc nulls last", u.id))
  end

  def cast_params(params) do
    param_types = %{
      max_id: :string,
      since_id: :string,
      limit: :integer
    }

    changeset = cast({%{}, param_types}, params, Map.keys(param_types))
    changeset.changes
  end

  defp restrict(query, :max_id, %{max_id: max_id}) do
    query
    |> where([q], q.id < ^max_id)
  end

  defp restrict(query, :since_id, %{since_id: since_id}) do
    query
    |> where([q], q.id > ^since_id)
  end

  defp restrict(query, :limit, options) do
    limit = Map.get(options, :limit, @default_limit)

    query
    |> limit(^limit)
  end

  defp restrict(query, _, _), do: query
end
