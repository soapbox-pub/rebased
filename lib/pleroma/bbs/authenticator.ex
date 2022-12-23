# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.BBS.Authenticator do
  use Sshd.PasswordAuthenticator
  alias Pleroma.User
  alias Pleroma.Web.Plugs.AuthenticationPlug

  def authenticate(username, password) do
    username = to_string(username)
    password = to_string(password)

    with %User{} = user <- User.get_by_nickname(username) do
      AuthenticationPlug.checkpw(password, user.password_hash)
    else
      _e -> false
    end
  end
end
