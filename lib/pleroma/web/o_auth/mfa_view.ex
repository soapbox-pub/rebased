# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.MFAView do
  use Pleroma.Web, :view
  import Phoenix.HTML.Form
  alias Pleroma.MFA
  alias Pleroma.Web.Gettext

  def render("mfa_response.json", %{token: token, user: user}) do
    %{
      error: "mfa_required",
      mfa_token: token.token,
      supported_challenge_types: MFA.supported_methods(user)
    }
  end
end
