# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.EmailList do
  @moduledoc """
  Functions for generating email lists from local users.
  """
  import Ecto.Query

  alias Pleroma.Repo
  alias Pleroma.User

  @header_row ["Email Address"]

  defp subscribers_query do
    User.Query.build(%{
      local: true,
      is_active: true,
      is_approved: true,
      is_confirmed: true,
      accepts_email_list: true
    })
    |> where([u], not is_nil(u.email))
  end

  def generate_csv do
    subscribers_query()
    |> generate_csv()
  end

  def generate_csv(query) do
    query
    |> Repo.all()
    |> Enum.map(&build_row/1)
    |> build_csv()
  end

  defp build_row(%User{email: email}), do: [email]

  defp build_csv(lines) do
    [@header_row | lines]
    |> CSV.encode()
    |> Enum.join()
  end
end
