# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Docs.Translator do
  require Pleroma.Docs.Translator.Compiler
  require Pleroma.Web.Gettext

  @before_compile Pleroma.Docs.Translator.Compiler
end
