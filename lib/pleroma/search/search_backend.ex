defmodule Pleroma.Search.SearchBackend do
  @doc """
  Search statuses with a query, restricting to only those the user should have access to.
  """
  @callback search(user :: Pleroma.User.t(), query :: String.t(), options :: [any()]) :: [
              Pleroma.Activity.t()
            ]

  @doc """
  Add the object associated with the activity to the search index.

  The whole activity is passed, to allow filtering on things such as scope.
  """
  @callback add_to_index(activity :: Pleroma.Activity.t()) :: :ok | {:error, any()}

  @doc """
  Remove the object from the index.

  Just the object, as opposed to the whole activity, is passed, since the object
  is what contains the actual content and there is no need for filtering when removing
  from index.
  """
  @callback remove_from_index(object :: Pleroma.Object.t()) :: :ok | {:error, any()}

  @doc """
  Create the index
  """
  @callback create_index() :: :ok | {:error, any()}

  @doc """
  Drop the index
  """
  @callback drop_index() :: :ok | {:error, any()}

  @doc """
  Healthcheck endpoints of search backend infrastructure to monitor for controlling
  processing of jobs in the Oban queue.

  It is expected a 200 response is healthy and other responses are unhealthy.
  """
  @callback healthcheck_endpoints :: list() | nil
end
