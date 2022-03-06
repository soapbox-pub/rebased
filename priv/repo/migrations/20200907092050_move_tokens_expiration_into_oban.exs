# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.MoveTokensExpirationIntoOban do
  use Ecto.Migration

  import Ecto.Query, only: [from: 2]

  def change do
    Pleroma.Config.Oban.warn()

    Application.ensure_all_started(:oban)

    Supervisor.start_link([{Oban, Pleroma.Config.get(Oban)}],
      strategy: :one_for_one,
      name: Pleroma.Supervisor
    )

    if Pleroma.Config.get([:oauth2, :clean_expired_tokens]) do
      from(t in Pleroma.Web.OAuth.Token, where: t.valid_until > ^NaiveDateTime.utc_now())
      |> Pleroma.Repo.stream()
      |> Stream.each(fn token ->
        Pleroma.Workers.PurgeExpiredToken.enqueue(%{
          token_id: token.id,
          valid_until: DateTime.from_naive!(token.valid_until, "Etc/UTC"),
          mod: Pleroma.Web.OAuth.Token
        })
      end)
      |> Stream.run()
    end

    from(t in Pleroma.MFA.Token, where: t.valid_until > ^NaiveDateTime.utc_now())
    |> Pleroma.Repo.stream()
    |> Stream.each(fn token ->
      Pleroma.Workers.PurgeExpiredToken.enqueue(%{
        token_id: token.id,
        valid_until: DateTime.from_naive!(token.valid_until, "Etc/UTC"),
        mod: Pleroma.MFA.Token
      })
    end)
    |> Stream.run()
  end
end
