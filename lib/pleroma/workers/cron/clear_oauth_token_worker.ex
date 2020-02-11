# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.Cron.ClearOauthTokenWorker do
  @moduledoc """
  The worker to cleanup expired oAuth tokens.
  """

  use Oban.Worker, queue: "background"

  alias Pleroma.Config
  alias Pleroma.Web.OAuth.Token

  @impl Oban.Worker
  def perform(_opts, _job) do
    if Config.get([:oauth2, :clean_expired_tokens], false) do
      Token.delete_expired_tokens()
    end
  end
end
