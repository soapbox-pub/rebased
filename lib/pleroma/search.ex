defmodule Pleroma.Search do
  def add_to_index(activity) do
    search_module = Pleroma.Config.get([Pleroma.Search, :module])

    ConcurrentLimiter.limit(Pleroma.Search, fn ->
      Task.start(fn -> search_module.add_to_index(activity) end)
    end)
  end

  def remove_from_index(object) do
    # Also delete from search index
    search_module = Pleroma.Config.get([Pleroma.Search, :module])

    ConcurrentLimiter.limit(Pleroma.Search, fn ->
      Task.start(fn -> search_module.remove_from_index(object) end)
    end)
  end

  def search(query, options) do
    search_module = Pleroma.Config.get([Pleroma.Search, :module], Pleroma.Activity)

    search_module.search(options[:for_user], query, options)
  end
end
