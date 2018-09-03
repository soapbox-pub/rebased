defmodule Pleroma.FilterTest do
  alias Pleroma.{User, Repo}
  use Pleroma.DataCase

  import Pleroma.Factory
  import Ecto.Query

  test "creating a filter" do
    user = insert(:user)

    query = %Pleroma.Filter{
      user_id: user.id,
      filter_id: 42,
      phrase: "knights",
      context: ["home"]
    }

    {:ok, %Pleroma.Filter{} = filter} = Pleroma.Filter.create(query)
    result = Pleroma.Filter.get(filter.filter_id, user)
    assert query.phrase == result.phrase
  end

  test "deleting a filter" do
    user = insert(:user)

    query = %Pleroma.Filter{
      user_id: user.id,
      filter_id: 0,
      phrase: "knights",
      context: ["home"]
    }

    {:ok, filter} = Pleroma.Filter.create(query)
    {:ok, filter} = Pleroma.Filter.delete(query)
    assert is_nil(Repo.get(Pleroma.Filter, filter.filter_id))
  end

  test "getting all filters by an user" do
    user = insert(:user)

    query_one = %Pleroma.Filter{
      user_id: user.id,
      filter_id: 1,
      phrase: "knights",
      context: ["home"]
    }

    query_two = %Pleroma.Filter{
      user_id: user.id,
      filter_id: 2,
      phrase: "who",
      context: ["home"]
    }

    {:ok, filter_one} = Pleroma.Filter.create(query_one)
    {:ok, filter_two} = Pleroma.Filter.create(query_two)
    filters = Pleroma.Filter.get_filters(user)
    assert filter_one in filters
    assert filter_two in filters
  end

  test "updating a filter" do
    user = insert(:user)

    query_one = %Pleroma.Filter{
      user_id: user.id,
      filter_id: 1,
      phrase: "knights",
      context: ["home"]
    }

    query_two = %Pleroma.Filter{
      user_id: user.id,
      filter_id: 1,
      phrase: "who",
      context: ["home", "timeline"]
    }

    {:ok, filter_one} = Pleroma.Filter.create(query_one)
    {:ok, filter_two} = Pleroma.Filter.update(query_two)
    assert filter_one != filter_two
    assert filter_two.phrase == query_two.phrase
    assert filter_two.context == query_two.context
  end
end
