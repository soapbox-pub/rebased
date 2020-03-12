# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.BBS.Authenticator do
  use Sshd.PasswordAuthenticator
  alias Comeonin.Pbkdf2
  alias Pleroma.User

  def authenticate(username, password) do
    username = to_string(username)
    password = to_string(password)

    with %User{} = user <- User.get_by_nickname(username) do
      Pbkdf2.checkpw(password, user.password_hash)
    else
      _e -> false
    end
  end
end
