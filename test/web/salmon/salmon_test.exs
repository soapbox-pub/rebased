# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Salmon.SalmonTest do
  use Pleroma.DataCase
  alias Pleroma.Activity
  alias Pleroma.Keys
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.Federator.Publisher
  alias Pleroma.Web.Salmon
  import Mock
  import Pleroma.Factory

  @magickey "RSA.pu0s-halox4tu7wmES1FVSx6u-4wc0YrUFXcqWXZG4-27UmbCOpMQftRCldNRfyA-qLbz-eqiwQhh-1EwUvjsD4cYbAHNGHwTvDOyx5AKthQUP44ykPv7kjKGh3DWKySJvcs9tlUG87hlo7AvnMo9pwRS_Zz2CacQ-MKaXyDepk=.AQAB"

  @wrong_magickey "RSA.pu0s-halox4tu7wmES1FVSx6u-4wc0YrUFXcqWXZG4-27UmbCOpMQftRCldNRfyA-qLbz-eqiwQhh-1EwUvjsD4cYbAHNGHwTvDOyx5AKthQUP44ykPv7kjKGh3DWKySJvcs9tlUG87hlo7AvnMo9pwRS_Zz2CacQ-MKaXyDepk=.AQAA"

  @magickey_friendica "RSA.AMwa8FUs2fWEjX0xN7yRQgegQffhBpuKNC6fa5VNSVorFjGZhRrlPMn7TQOeihlc9lBz2OsHlIedbYn2uJ7yCs0.AQAB"

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "decodes a salmon" do
    {:ok, salmon} = File.read("test/fixtures/salmon.xml")
    {:ok, doc} = Salmon.decode_and_validate(@magickey, salmon)
    assert Regex.match?(~r/xml/, doc)
  end

  test "errors on wrong magic key" do
    {:ok, salmon} = File.read("test/fixtures/salmon.xml")
    assert Salmon.decode_and_validate(@wrong_magickey, salmon) == :error
  end

  test "it encodes a magic key from a public key" do
    key = Salmon.decode_key(@magickey)
    magic_key = Salmon.encode_key(key)

    assert @magickey == magic_key
  end

  test "it decodes a friendica public key" do
    _key = Salmon.decode_key(@magickey_friendica)
  end

  test "encodes an xml payload with a private key" do
    doc = File.read!("test/fixtures/incoming_note_activity.xml")
    pem = File.read!("test/fixtures/private_key.pem")
    {:ok, private, public} = Keys.keys_from_pem(pem)

    # Let's try a roundtrip.
    {:ok, salmon} = Salmon.encode(private, doc)
    {:ok, decoded_doc} = Salmon.decode_and_validate(Salmon.encode_key(public), salmon)

    assert doc == decoded_doc
  end

  test "it gets a magic key" do
    salmon = File.read!("test/fixtures/salmon2.xml")
    {:ok, key} = Salmon.fetch_magic_key(salmon)

    assert key ==
             "RSA.uzg6r1peZU0vXGADWxGJ0PE34WvmhjUmydbX5YYdOiXfODVLwCMi1umGoqUDm-mRu4vNEdFBVJU1CpFA7dKzWgIsqsa501i2XqElmEveXRLvNRWFB6nG03Q5OUY2as8eE54BJm0p20GkMfIJGwP6TSFb-ICp3QjzbatuSPJ6xCE=.AQAB"
  end

  test_with_mock "it pushes an activity to remote accounts it's addressed to",
                 Publisher,
                 [:passthrough],
                 [] do
    user_data = %{
      info: %{
        salmon: "http://test-example.org/salmon"
      },
      local: false
    }

    mentioned_user = insert(:user, user_data)
    note = insert(:note)

    activity_data = %{
      "id" => Pleroma.Web.ActivityPub.Utils.generate_activity_id(),
      "type" => "Create",
      "actor" => note.data["actor"],
      "to" => note.data["to"] ++ [mentioned_user.ap_id],
      "object" => note.data,
      "published_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "context" => note.data["context"]
    }

    {:ok, activity} = Repo.insert(%Activity{data: activity_data, recipients: activity_data["to"]})
    user = User.get_cached_by_ap_id(activity.data["actor"])
    {:ok, user} = User.ensure_keys_present(user)

    Salmon.publish(user, activity)

    assert called(Publisher.enqueue_one(Salmon, %{recipient_id: mentioned_user.id}))
  end
end
