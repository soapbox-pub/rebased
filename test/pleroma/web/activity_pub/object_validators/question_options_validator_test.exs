# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.QuestionOptionsValidatorTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.ObjectValidators.QuestionOptionsValidator

  describe "Validates Question options" do
    test "" do
      name_map = %{
        "en-US" => "mew",
        "en-GB" => "meow"
      }

      data = %{
        "type" => "Note",
        "name" => "mew",
        "nameMap" => name_map
      }

      assert %{valid?: true, changes: %{nameMap: ^name_map}} =
               QuestionOptionsValidator.changeset(%QuestionOptionsValidator{}, data)
    end
  end
end
