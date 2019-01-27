# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

alias Pleroma.Repo
alias Pleroma.User
alias Pleroma.Activity
alias Pleroma.Object
import Ecto.Query

defmodule Pleroma.SpcFixes do
  def upgrade_users do
    query =
      from(u in User,
        where: fragment("? like ?", u.ap_id, "https://shitposter.club/user/%")
      )

    {:ok, file} = File.read("lib/pleroma/spc_fixes/users_conversion.txt")

    # Mapping of old ap_id to new ap_id and vice reversa
    mapping =
      file
      |> String.trim()
      |> String.split("\n")
      |> Enum.map(fn line ->
        line
        |> String.split("\t")
      end)
      |> Enum.reduce(%{}, fn [_id, old_ap_id, new_ap_id], acc ->
        acc
        |> Map.put(String.trim(old_ap_id), String.trim(new_ap_id))
        |> Map.put(String.trim(new_ap_id), String.trim(old_ap_id))
      end)

    # First, refetch all the old users.
    _old_users =
      query
      |> Repo.all()
      |> Enum.each(fn user ->
        with ap_id when is_binary(ap_id) <- mapping[user.ap_id] do
          # This fetches and updates the user.
          User.get_or_fetch_by_ap_id(ap_id)
        end
      end)

    # Now, fix follow relationships.
    query =
      from(u in User,
        where: fragment("? like ?", u.ap_id, "https://shitposter.club/users/%")
      )

    query
    |> Repo.all()
    |> Enum.each(fn user ->
      old_follower_address = User.ap_followers(user)

      # Fix users
      query =
        from(u in User,
          where: ^old_follower_address in u.following,
          update: [
            push: [following: ^user.follower_address]
          ]
        )

      Repo.update_all(query, [])

      # Fix activities
      query =
        from(a in Activity,
          where: fragment("?->>'actor' = ?", a.data, ^mapping[user.ap_id]),
          update: [
            set: [
              data:
                fragment(
                  "jsonb_set(jsonb_set(?, '{actor}', ?), '{to}', (?->'to')::jsonb || ?)",
                  a.data,
                  ^user.ap_id,
                  a.data,
                  ^[user.follower_address]
                ),
              actor: ^user.ap_id
            ],
            push: [
              recipients: ^user.follower_address
            ]
          ]
        )

      Repo.update_all(query, [])

      # Fix objects
      query =
        from(a in Object,
          where: fragment("?->>'actor' = ?", a.data, ^mapping[user.ap_id]),
          update: [
            set: [
              data:
                fragment(
                  "jsonb_set(jsonb_set(?, '{actor}', ?), '{to}', (?->'to')::jsonb || ?)",
                  a.data,
                  ^user.ap_id,
                  a.data,
                  ^[user.follower_address]
                )
            ]
          ]
        )

      Repo.update_all(query, [])
    end)
  end
end
