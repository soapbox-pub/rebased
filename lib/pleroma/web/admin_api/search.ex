# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.Search do
  import Ecto.Query

  alias Pleroma.Repo
  alias Pleroma.User

  @page_size 50

  @spec user(map()) :: {:ok, [User.t()], pos_integer()}
  def user(params \\ %{}) do
    query =
      params
      |> Map.drop([:page, :page_size])
      |> Map.put(:invisible, false)
      |> User.Query.build()
      |> order_by(desc: :id)

    paginated_query =
      User.Query.paginate(query, params[:page] || 1, params[:page_size] || @page_size)

    count = Repo.aggregate(query, :count, :id)

    results = Repo.all(paginated_query)
    {:ok, results, count}
  end
end
