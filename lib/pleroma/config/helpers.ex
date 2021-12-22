# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Config.Helpers do
  alias Pleroma.Config

  def instance_name, do: Config.get([:instance, :name])

  defp instance_notify_email do
    Config.get([:instance, :notify_email]) || Config.get([:instance, :email])
  end

  def sender do
    {instance_name(), instance_notify_email()}
  end
end
