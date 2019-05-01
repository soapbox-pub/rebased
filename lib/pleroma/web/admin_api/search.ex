# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.Search do
  import Ecto.Query

  alias Pleroma.Repo
  alias Pleroma.User

  @page_size 50

  def user(%{query: term} = params) when is_nil(term) or term == "" do
    query = maybe_filtered_query(params)

    paginated_query =
      maybe_filtered_query(params)
      |> paginate(params[:page] || 1, params[:page_size] || @page_size)

    count = query |> Repo.aggregate(:count, :id)

    results = Repo.all(paginated_query)

    {:ok, results, count}
  end

  def user(%{query: term} = params) when is_binary(term) do
    search_query = from(u in maybe_filtered_query(params), where: ilike(u.nickname, ^"%#{term}%"))

    count = search_query |> Repo.aggregate(:count, :id)

    results =
      search_query
      |> paginate(params[:page] || 1, params[:page_size] || @page_size)
      |> Repo.all()

    {:ok, results, count}
  end

  defp maybe_filtered_query(params) do
    from(u in User, order_by: u.nickname)
    |> User.maybe_local_user_query(params[:local])
    |> User.maybe_external_user_query(params[:external])
    |> User.maybe_active_user_query(params[:active])
    |> User.maybe_deactivated_user_query(params[:deactivated])
  end

  defp paginate(query, page, page_size) do
    from(u in query,
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
  end
end
