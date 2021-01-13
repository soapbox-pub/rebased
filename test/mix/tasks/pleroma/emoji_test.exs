# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.EmojiTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Tesla.Mock

  alias Mix.Tasks.Pleroma.Emoji

  describe "ls-packs" do
    test "with default manifest as url" do
      mock(fn
        %{
          method: :get,
          url: "https://git.pleroma.social/pleroma/emoji-index/raw/master/index.json"
        } ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/emoji/packs/default-manifest.json")
          }
      end)

      capture_io(fn -> Emoji.run(["ls-packs"]) end) =~
        "https://finland.fi/wp-content/uploads/2017/06/finland-emojis.zip"
    end

    test "with passed manifest as file" do
      capture_io(fn ->
        Emoji.run(["ls-packs", "-m", "test/fixtures/emoji/packs/manifest.json"])
      end) =~ "https://git.pleroma.social/pleroma/emoji-index/raw/master/packs/blobs_gg.zip"
    end
  end

  describe "get-packs" do
    test "download pack from default manifest" do
      mock(fn
        %{
          method: :get,
          url: "https://git.pleroma.social/pleroma/emoji-index/raw/master/index.json"
        } ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/emoji/packs/default-manifest.json")
          }

        %{
          method: :get,
          url: "https://finland.fi/wp-content/uploads/2017/06/finland-emojis.zip"
        } ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/emoji/packs/blank.png.zip")
          }

        %{
          method: :get,
          url: "https://git.pleroma.social/pleroma/emoji-index/raw/master/finmoji.json"
        } ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/emoji/packs/finmoji.json")
          }
      end)

      assert capture_io(fn -> Emoji.run(["get-packs", "finmoji"]) end) =~ "Writing pack.json for"

      emoji_path =
        Path.join(
          Pleroma.Config.get!([:instance, :static_dir]),
          "emoji"
        )

      assert File.exists?(Path.join([emoji_path, "finmoji", "pack.json"]))
      on_exit(fn -> File.rm_rf!("test/instance_static/emoji/finmoji") end)
    end

    test "install local emoji pack" do
      assert capture_io(fn ->
               Emoji.run([
                 "get-packs",
                 "local",
                 "--manifest",
                 "test/instance_static/local_pack/manifest.json"
               ])
             end) =~ "Writing pack.json for"

      on_exit(fn -> File.rm_rf!("test/instance_static/emoji/local") end)
    end

    test "pack not found" do
      mock(fn
        %{
          method: :get,
          url: "https://git.pleroma.social/pleroma/emoji-index/raw/master/index.json"
        } ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/emoji/packs/default-manifest.json")
          }
      end)

      assert capture_io(fn -> Emoji.run(["get-packs", "not_found"]) end) =~
               "No pack named \"not_found\" found"
    end

    test "raise on bad sha256" do
      mock(fn
        %{
          method: :get,
          url: "https://git.pleroma.social/pleroma/emoji-index/raw/master/packs/blobs_gg.zip"
        } ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/emoji/packs/blank.png.zip")
          }
      end)

      assert_raise RuntimeError, ~r/^Bad SHA256 for blobs.gg/, fn ->
        capture_io(fn ->
          Emoji.run(["get-packs", "blobs.gg", "-m", "test/fixtures/emoji/packs/manifest.json"])
        end)
      end
    end
  end

  describe "gen-pack" do
    setup do
      url = "https://finland.fi/wp-content/uploads/2017/06/finland-emojis.zip"

      mock(fn %{
                method: :get,
                url: ^url
              } ->
        %Tesla.Env{status: 200, body: File.read!("test/fixtures/emoji/packs/blank.png.zip")}
      end)

      {:ok, url: url}
    end

    test "with default extensions", %{url: url} do
      name = "pack1"
      pack_json = "#{name}.json"
      files_json = "#{name}_file.json"
      refute File.exists?(pack_json)
      refute File.exists?(files_json)

      captured =
        capture_io(fn ->
          Emoji.run([
            "gen-pack",
            url,
            "--name",
            name,
            "--license",
            "license",
            "--homepage",
            "homepage",
            "--description",
            "description",
            "--files",
            files_json,
            "--extensions",
            ".png .gif"
          ])
        end)

      assert captured =~ "#{pack_json} has been created with the pack1 pack"
      assert captured =~ "Using .png .gif extensions"

      assert File.exists?(pack_json)
      assert File.exists?(files_json)

      on_exit(fn ->
        File.rm!(pack_json)
        File.rm!(files_json)
      end)
    end

    test "with custom extensions and update existing files", %{url: url} do
      name = "pack2"
      pack_json = "#{name}.json"
      files_json = "#{name}_file.json"
      refute File.exists?(pack_json)
      refute File.exists?(files_json)

      captured =
        capture_io(fn ->
          Emoji.run([
            "gen-pack",
            url,
            "--name",
            name,
            "--license",
            "license",
            "--homepage",
            "homepage",
            "--description",
            "description",
            "--files",
            files_json,
            "--extensions",
            " .png   .gif    .jpeg "
          ])
        end)

      assert captured =~ "#{pack_json} has been created with the pack2 pack"
      assert captured =~ "Using .png .gif .jpeg extensions"

      assert File.exists?(pack_json)
      assert File.exists?(files_json)

      captured =
        capture_io(fn ->
          Emoji.run([
            "gen-pack",
            url,
            "--name",
            name,
            "--license",
            "license",
            "--homepage",
            "homepage",
            "--description",
            "description",
            "--files",
            files_json,
            "--extensions",
            " .png   .gif    .jpeg "
          ])
        end)

      assert captured =~ "#{pack_json} has been updated with the pack2 pack"

      on_exit(fn ->
        File.rm!(pack_json)
        File.rm!(files_json)
      end)
    end
  end
end
