# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Scopes.Translator do
  require Pleroma.Web.ApiSpec.Scopes.Compiler
  require Pleroma.Web.Gettext

  @before_compile Pleroma.Web.ApiSpec.Scopes.Compiler
end
