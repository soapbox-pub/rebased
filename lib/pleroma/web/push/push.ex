# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Push do
  alias Pleroma.Repo
  alias Pleroma.Workers.WebPusher

  require Logger

  defdelegate worker_args(queue), to: Pleroma.Workers.Helper

  def init do
    unless enabled() do
      Logger.warn("""
      VAPID key pair is not found. If you wish to enabled web push, please run

          mix web_push.gen.keypair

      and add the resulting output to your configuration file.
      """)
    end
  end

  def vapid_config do
    Application.get_env(:web_push_encryption, :vapid_details, [])
  end

  def enabled do
    case vapid_config() do
      [] -> false
      list when is_list(list) -> true
      _ -> false
    end
  end

  def send(notification) do
    %{"op" => "web_push", "notification_id" => notification.id}
    |> WebPusher.new(worker_args(:web_push))
    |> Repo.insert()
  end
end
