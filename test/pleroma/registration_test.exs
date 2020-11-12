# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.RegistrationTest do
  use Pleroma.DataCase

  import Pleroma.Factory

  alias Pleroma.Registration
  alias Pleroma.Repo

  describe "generic changeset" do
    test "requires :provider, :uid" do
      registration = build(:registration, provider: nil, uid: nil)

      cs = Registration.changeset(registration, %{})
      refute cs.valid?

      assert [
               provider: {"can't be blank", [validation: :required]},
               uid: {"can't be blank", [validation: :required]}
             ] == cs.errors
    end

    test "ensures uniqueness of [:provider, :uid]" do
      registration = insert(:registration)
      registration2 = build(:registration, provider: registration.provider, uid: registration.uid)

      cs = Registration.changeset(registration2, %{})
      assert cs.valid?

      assert {:error,
              %Ecto.Changeset{
                errors: [
                  uid:
                    {"has already been taken",
                     [constraint: :unique, constraint_name: "registrations_provider_uid_index"]}
                ]
              }} = Repo.insert(cs)

      # Note: multiple :uid values per [:user_id, :provider] are intentionally allowed
      cs2 = Registration.changeset(registration2, %{uid: "available.uid"})
      assert cs2.valid?
      assert {:ok, _} = Repo.insert(cs2)

      cs3 = Registration.changeset(registration2, %{provider: "provider2"})
      assert cs3.valid?
      assert {:ok, _} = Repo.insert(cs3)
    end

    test "allows `nil` :user_id (user-unbound registration)" do
      registration = build(:registration, user_id: nil)
      cs = Registration.changeset(registration, %{})
      assert cs.valid?
      assert {:ok, _} = Repo.insert(cs)
    end
  end
end
