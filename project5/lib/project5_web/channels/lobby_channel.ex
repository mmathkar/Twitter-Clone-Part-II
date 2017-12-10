defmodule Chatroom.LobbyChannel do
  use Phoenix.Channel

  def join("lobby", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("subscribeTo", payload, socket) do
    username = Map.get(payload, "message")
    selfId = Map.get(payload, "name")
    mapSet =
      if :ets.lookup(:followersTable, username) == [] do
          MapSet.new
      else
          [{_, set}] = :ets.lookup(:followersTable, username)
          set
      end

      mapSet = MapSet.put(mapSet, selfId)

      :ets.insert(:followersTable, {username, mapSet})ç

      mapSet2 = 
      if :ets.lookup(:followsTable, selfId) == [] do
        MapSet.new
      else
       [{_, set}] = :ets.lookup(:followsTable, selfId)
       set
      end 

      mapSet2 = MapSet.put(mapSet2, username)
      # followsTable = Map.put(followsTable, selfId, mapSet2)
      :ets.insert(:followsTable, {selfId, mapSet2})

    broadcast! socket, "subscribeTo", payload
    {:noreply, socket}
  end
end