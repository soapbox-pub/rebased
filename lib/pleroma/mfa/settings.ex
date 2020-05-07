# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.MFA.Settings do
  use Ecto.Schema

  @primary_key false

  @mfa_methods [:totp]
  embedded_schema do
    field(:enabled, :boolean, default: false)
    field(:backup_codes, {:array, :string}, default: [])

    embeds_one :totp, TOTP, on_replace: :delete, primary_key: false do
      field(:secret, :string)
      # app | sms
      field(:delivery_type, :string, default: "app")
      field(:confirmed, :boolean, default: false)
    end
  end

  def mfa_methods, do: @mfa_methods
end
