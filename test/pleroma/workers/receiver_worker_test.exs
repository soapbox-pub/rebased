# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.ReceiverWorkerTest do
  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  import Mock
  import Pleroma.Factory

  alias Pleroma.Web.Federator
  alias Pleroma.Workers.ReceiverWorker

  test "it does not retry MRF reject" do
    params = insert(:note).data

    with_mock Pleroma.Web.ActivityPub.Transmogrifier,
      handle_incoming: fn _ -> {:reject, "MRF"} end do
      assert {:cancel, {:reject, "MRF"}} =
               ReceiverWorker.perform(%Oban.Job{
                 args: %{"op" => "incoming_ap_doc", "params" => params}
               })
    end
  end

  test "it does not retry ObjectValidator reject" do
    params =
      insert(:note_activity).data
      |> Map.put("id", Pleroma.Web.ActivityPub.Utils.generate_activity_id())
      |> Map.put("object", %{
        "type" => "Note",
        "id" => Pleroma.Web.ActivityPub.Utils.generate_object_id()
      })

    with_mock Pleroma.Web.ActivityPub.ObjectValidator, [:passthrough],
      validate: fn _, _ -> {:error, %Ecto.Changeset{}} end do
      assert {:cancel, {:error, %Ecto.Changeset{}}} =
               ReceiverWorker.perform(%Oban.Job{
                 args: %{"op" => "incoming_ap_doc", "params" => params}
               })
    end
  end

  test "it does not retry duplicates" do
    params = insert(:note_activity).data

    assert {:cancel, :already_present} =
             ReceiverWorker.perform(%Oban.Job{
               args: %{"op" => "incoming_ap_doc", "params" => params}
             })
  end

  test "it can validate the signature" do
    Tesla.Mock.mock(fn
      %{url: "https://mastodon.social/users/bastianallgeier"} ->
        %Tesla.Env{
          status: 200,
          body: File.read!("test/fixtures/bastianallgeier.json"),
          headers: [{"content-type", "application/activity+json"}]
        }

      %{url: "https://mastodon.social/users/bastianallgeier/collections/featured"} ->
        %Tesla.Env{
          status: 200,
          headers: [{"content-type", "application/activity+json"}],
          body:
            File.read!("test/fixtures/users_mock/masto_featured.json")
            |> String.replace("{{domain}}", "mastodon.social")
            |> String.replace("{{nickname}}", "bastianallgeier")
        }

      %{url: "https://phpc.social/users/denniskoch"} ->
        %Tesla.Env{
          status: 200,
          body: File.read!("test/fixtures/denniskoch.json"),
          headers: [{"content-type", "application/activity+json"}]
        }

      %{url: "https://phpc.social/users/denniskoch/collections/featured"} ->
        %Tesla.Env{
          status: 200,
          headers: [{"content-type", "application/activity+json"}],
          body:
            File.read!("test/fixtures/users_mock/masto_featured.json")
            |> String.replace("{{domain}}", "phpc.social")
            |> String.replace("{{nickname}}", "denniskoch")
        }

      %{url: "https://mastodon.social/users/bastianallgeier/statuses/112846516276907281"} ->
        %Tesla.Env{
          status: 200,
          headers: [{"content-type", "application/activity+json"}],
          body: File.read!("test/fixtures/receiver_worker_signature_activity.json")
        }
    end)

    params = %{
      "@context" => [
        "https://www.w3.org/ns/activitystreams",
        "https://w3id.org/security/v1",
        %{
          "claim" => %{"@id" => "toot:claim", "@type" => "@id"},
          "memorial" => "toot:memorial",
          "atomUri" => "ostatus:atomUri",
          "manuallyApprovesFollowers" => "as:manuallyApprovesFollowers",
          "blurhash" => "toot:blurhash",
          "ostatus" => "http://ostatus.org#",
          "discoverable" => "toot:discoverable",
          "focalPoint" => %{"@container" => "@list", "@id" => "toot:focalPoint"},
          "votersCount" => "toot:votersCount",
          "Hashtag" => "as:Hashtag",
          "Emoji" => "toot:Emoji",
          "alsoKnownAs" => %{"@id" => "as:alsoKnownAs", "@type" => "@id"},
          "sensitive" => "as:sensitive",
          "movedTo" => %{"@id" => "as:movedTo", "@type" => "@id"},
          "inReplyToAtomUri" => "ostatus:inReplyToAtomUri",
          "conversation" => "ostatus:conversation",
          "Device" => "toot:Device",
          "schema" => "http://schema.org#",
          "toot" => "http://joinmastodon.org/ns#",
          "cipherText" => "toot:cipherText",
          "suspended" => "toot:suspended",
          "messageType" => "toot:messageType",
          "featuredTags" => %{"@id" => "toot:featuredTags", "@type" => "@id"},
          "Curve25519Key" => "toot:Curve25519Key",
          "deviceId" => "toot:deviceId",
          "Ed25519Signature" => "toot:Ed25519Signature",
          "featured" => %{"@id" => "toot:featured", "@type" => "@id"},
          "devices" => %{"@id" => "toot:devices", "@type" => "@id"},
          "value" => "schema:value",
          "PropertyValue" => "schema:PropertyValue",
          "messageFranking" => "toot:messageFranking",
          "publicKeyBase64" => "toot:publicKeyBase64",
          "identityKey" => %{"@id" => "toot:identityKey", "@type" => "@id"},
          "Ed25519Key" => "toot:Ed25519Key",
          "indexable" => "toot:indexable",
          "EncryptedMessage" => "toot:EncryptedMessage",
          "fingerprintKey" => %{"@id" => "toot:fingerprintKey", "@type" => "@id"}
        }
      ],
      "actor" => "https://phpc.social/users/denniskoch",
      "cc" => [
        "https://phpc.social/users/denniskoch/followers",
        "https://mastodon.social/users/bastianallgeier",
        "https://chaos.social/users/distantnative",
        "https://fosstodon.org/users/kev"
      ],
      "id" => "https://phpc.social/users/denniskoch/statuses/112847382711461301/activity",
      "object" => %{
        "atomUri" => "https://phpc.social/users/denniskoch/statuses/112847382711461301",
        "attachment" => [],
        "attributedTo" => "https://phpc.social/users/denniskoch",
        "cc" => [
          "https://phpc.social/users/denniskoch/followers",
          "https://mastodon.social/users/bastianallgeier",
          "https://chaos.social/users/distantnative",
          "https://fosstodon.org/users/kev"
        ],
        "content" =>
          "<p><span class=\"h-card\" translate=\"no\"><a href=\"https://mastodon.social/@bastianallgeier\" class=\"u-url mention\">@<span>bastianallgeier</span></a></span> <span class=\"h-card\" translate=\"no\"><a href=\"https://chaos.social/@distantnative\" class=\"u-url mention\">@<span>distantnative</span></a></span> <span class=\"h-card\" translate=\"no\"><a href=\"https://fosstodon.org/@kev\" class=\"u-url mention\">@<span>kev</span></a></span> Another main argument: Discord is popular. Many people have an account, so you can just join an server quickly. Also you know the app and how to get around.</p>",
        "contentMap" => %{
          "en" =>
            "<p><span class=\"h-card\" translate=\"no\"><a href=\"https://mastodon.social/@bastianallgeier\" class=\"u-url mention\">@<span>bastianallgeier</span></a></span> <span class=\"h-card\" translate=\"no\"><a href=\"https://chaos.social/@distantnative\" class=\"u-url mention\">@<span>distantnative</span></a></span> <span class=\"h-card\" translate=\"no\"><a href=\"https://fosstodon.org/@kev\" class=\"u-url mention\">@<span>kev</span></a></span> Another main argument: Discord is popular. Many people have an account, so you can just join an server quickly. Also you know the app and how to get around.</p>"
        },
        "conversation" =>
          "tag:mastodon.social,2024-07-25:objectId=760068442:objectType=Conversation",
        "id" => "https://phpc.social/users/denniskoch/statuses/112847382711461301",
        "inReplyTo" =>
          "https://mastodon.social/users/bastianallgeier/statuses/112846516276907281",
        "inReplyToAtomUri" =>
          "https://mastodon.social/users/bastianallgeier/statuses/112846516276907281",
        "published" => "2024-07-25T13:33:29Z",
        "replies" => %{
          "first" => %{
            "items" => [],
            "next" =>
              "https://phpc.social/users/denniskoch/statuses/112847382711461301/replies?only_other_accounts=true&page=true",
            "partOf" =>
              "https://phpc.social/users/denniskoch/statuses/112847382711461301/replies",
            "type" => "CollectionPage"
          },
          "id" => "https://phpc.social/users/denniskoch/statuses/112847382711461301/replies",
          "type" => "Collection"
        },
        "sensitive" => false,
        "tag" => [
          %{
            "href" => "https://mastodon.social/users/bastianallgeier",
            "name" => "@bastianallgeier@mastodon.social",
            "type" => "Mention"
          },
          %{
            "href" => "https://chaos.social/users/distantnative",
            "name" => "@distantnative@chaos.social",
            "type" => "Mention"
          },
          %{
            "href" => "https://fosstodon.org/users/kev",
            "name" => "@kev@fosstodon.org",
            "type" => "Mention"
          }
        ],
        "to" => ["https://www.w3.org/ns/activitystreams#Public"],
        "type" => "Note",
        "url" => "https://phpc.social/@denniskoch/112847382711461301"
      },
      "published" => "2024-07-25T13:33:29Z",
      "signature" => %{
        "created" => "2024-07-25T13:33:29Z",
        "creator" => "https://phpc.social/users/denniskoch#main-key",
        "signatureValue" =>
          "slz9BKJzd2n1S44wdXGOU+bV/wsskdgAaUpwxj8R16mYOL8+DTpE6VnfSKoZGsBBJT8uG5gnVfVEz1YsTUYtymeUgLMh7cvd8VnJnZPS+oixbmBRVky/Myf91TEgQQE7G4vDmTdB4ii54hZrHcOOYYf5FKPNRSkMXboKA6LMqNtekhbI+JTUJYIB02WBBK6PUyo15f6B1RJ6HGWVgud9NE0y1EZXfrkqUt682p8/9D49ORf7AwjXUJibKic2RbPvhEBj70qUGfBm4vvgdWhSUn1IG46xh+U0+NrTSUED82j1ZVOeua/2k/igkGs8cSBkY35quXTkPz6gbqCCH66CuA==",
        "type" => "RsaSignature2017"
      },
      "to" => ["https://www.w3.org/ns/activitystreams#Public"],
      "type" => "Create"
    }

    req_headers = [
      ["accept-encoding", "gzip"],
      ["content-length", "5184"],
      ["content-type", "application/activity+json"],
      ["date", "Thu, 25 Jul 2024 13:33:31 GMT"],
      ["digest", "SHA-256=ouge/6HP2/QryG6F3JNtZ6vzs/hSwMk67xdxe87eH7A="],
      ["host", "bikeshed.party"],
      [
        "signature",
        "keyId=\"https://mastodon.social/users/bastianallgeier#main-key\",algorithm=\"rsa-sha256\",headers=\"(request-target) host date digest content-type\",signature=\"ymE3vn5Iw50N6ukSp8oIuXJB5SBjGAGjBasdTDvn+ahZIzq2SIJfmVCsIIzyqIROnhWyQoTbavTclVojEqdaeOx+Ejz2wBnRBmhz5oemJLk4RnnCH0lwMWyzeY98YAvxi9Rq57Gojuv/1lBqyGa+rDzynyJpAMyFk17XIZpjMKuTNMCbjMDy76ILHqArykAIL/v1zxkgwxY/+ELzxqMpNqtZ+kQ29znNMUBB3eVZ/mNAHAz6o33Y9VKxM2jw+08vtuIZOusXyiHbRiaj2g5HtN2WBUw1MzzfRfHF2/yy7rcipobeoyk5RvP5SyHV3WrIeZ3iyoNfmv33y8fxllF0EA==\""
      ],
      [
        "user-agent",
        "http.rb/5.2.0 (Mastodon/4.3.0-nightly.2024-07-25; +https://mastodon.social/)"
      ]
    ]

    {:ok, oban_job} =
      Federator.incoming_ap_doc(%{
        method: "POST",
        req_headers: req_headers,
        request_path: "/inbox",
        params: params,
        query_string: ""
      })

    assert {:ok, %Pleroma.Activity{}} = ReceiverWorker.perform(oban_job)
  end
end
