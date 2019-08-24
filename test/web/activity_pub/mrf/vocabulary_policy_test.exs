# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.VocabularyPolicyTest do
  use Pleroma.DataCase

  alias Pleroma.Web.ActivityPub.MRF.VocabularyPolicy

  describe "accept" do
    clear_config([:mrf_vocabulary, :accept])

    test "it accepts based on parent activity type" do
      Pleroma.Config.put([:mrf_vocabulary, :accept], ["Like"])

      message = %{
        "type" => "Like",
        "object" => "whatever"
      }

      {:ok, ^message} = VocabularyPolicy.filter(message)
    end

    test "it accepts based on child object type" do
      Pleroma.Config.put([:mrf_vocabulary, :accept], ["Create", "Note"])

      message = %{
        "type" => "Create",
        "object" => %{
          "type" => "Note",
          "content" => "whatever"
        }
      }

      {:ok, ^message} = VocabularyPolicy.filter(message)
    end

    test "it does not accept disallowed child objects" do
      Pleroma.Config.put([:mrf_vocabulary, :accept], ["Create", "Note"])

      message = %{
        "type" => "Create",
        "object" => %{
          "type" => "Article",
          "content" => "whatever"
        }
      }

      {:reject, nil} = VocabularyPolicy.filter(message)
    end

    test "it does not accept disallowed parent types" do
      Pleroma.Config.put([:mrf_vocabulary, :accept], ["Announce", "Note"])

      message = %{
        "type" => "Create",
        "object" => %{
          "type" => "Note",
          "content" => "whatever"
        }
      }

      {:reject, nil} = VocabularyPolicy.filter(message)
    end
  end

  describe "reject" do
    clear_config([:mrf_vocabulary, :reject])

    test "it rejects based on parent activity type" do
      Pleroma.Config.put([:mrf_vocabulary, :reject], ["Like"])

      message = %{
        "type" => "Like",
        "object" => "whatever"
      }

      {:reject, nil} = VocabularyPolicy.filter(message)
    end

    test "it rejects based on child object type" do
      Pleroma.Config.put([:mrf_vocabulary, :reject], ["Note"])

      message = %{
        "type" => "Create",
        "object" => %{
          "type" => "Note",
          "content" => "whatever"
        }
      }

      {:reject, nil} = VocabularyPolicy.filter(message)
    end

    test "it passes through objects that aren't disallowed" do
      Pleroma.Config.put([:mrf_vocabulary, :reject], ["Like"])

      message = %{
        "type" => "Announce",
        "object" => "whatever"
      }

      {:ok, ^message} = VocabularyPolicy.filter(message)
    end
  end
end
