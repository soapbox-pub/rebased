defmodule Pleroma.Web.EmojiAPI.EmojiAPIControllerTest do
  use Pleroma.Web.ConnCase

  import Tesla.Mock

  import Pleroma.Factory

  test "shared & non-shared pack information in list_packs is ok" do
    conn = build_conn()
    resp = conn |> get(emoji_api_path(conn, :list_packs)) |> json_response(200)

    assert Map.has_key?(resp, "test_pack")

    pack = resp["test_pack"]

    assert Map.has_key?(pack["pack"], "download-sha256")
    assert pack["pack"]["can-download"]

    assert pack["files"] == %{"blank" => "blank.png"}

    # Non-shared pack

    assert Map.has_key?(resp, "test_pack_nonshared")

    pack = resp["test_pack_nonshared"]

    refute pack["pack"]["shared"]
    refute pack["pack"]["can-download"]
  end

  test "downloading a shared pack from download_shared" do
    conn = build_conn()

    resp =
      conn
      |> get(emoji_api_path(conn, :download_shared, "test_pack"))
      |> response(200)

    {:ok, arch} = :zip.unzip(resp, [:memory])

    assert Enum.find(arch, fn {n, _} -> n == 'pack.json' end)
    assert Enum.find(arch, fn {n, _} -> n == 'blank.png' end)
  end

  test "downloading a shared pack from another instance via download_from, deleting it" do
    on_exit(fn ->
      File.rm_rf!("test/instance_static/emoji/test_pack2")
    end)

    mock(fn
      %{
        method: :get,
        url: "https://example.com/api/pleroma/emoji/packs/list"
      } ->
        conn = build_conn()

        conn
        |> get(emoji_api_path(conn, :list_packs))
        |> json_response(200)
        |> json()

      %{
        method: :get,
        url: "https://example.com/api/pleroma/emoji/packs/download_shared/test_pack"
      } ->
        conn = build_conn()

        conn
        |> get(emoji_api_path(conn, :download_shared, "test_pack"))
        |> response(200)
        |> text()
    end)

    admin = insert(:user, info: %{is_admin: true})

    conn = build_conn()

    assert conn
           |> put_req_header("content-type", "application/json")
           |> assign(:user, admin)
           |> post(
             emoji_api_path(
               conn,
               :download_from
             ),
             %{
               instance_address: "https://example.com",
               pack_name: "test_pack",
               as: "test_pack2"
             }
             |> Jason.encode!()
           )
           |> text_response(200) == "ok"

    assert File.exists?("test/instance_static/emoji/test_pack2/pack.json")
    assert File.exists?("test/instance_static/emoji/test_pack2/blank.png")

    assert conn
           |> assign(:user, admin)
           |> delete(emoji_api_path(conn, :delete, "test_pack2"))
           |> response(200) == "ok"

    refute File.exists?("test/instance_static/emoji/test_pack2")
  end
end
