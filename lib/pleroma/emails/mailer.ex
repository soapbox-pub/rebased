# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Mailer do
  use Swoosh.Mailer, otp_app: :pleroma

  def deliver_async(email, config \\ []) do
    PleromaJobQueue.enqueue(:mailer, __MODULE__, [:deliver_async, email, config])
  end

  def perform(:deliver_async, email, config), do: deliver(email, config)
end
