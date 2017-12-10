defmodule Chatroom.LobbyChannel do
  use Phoenix.Channel

  def join("lobby", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("subscribeTo", payload, socket) do
    username = Map.get(payload, "username")
    selfId = Map.get(payload, "selfId")
    mapSet =
      if :ets.lookup(:followersTable, username) == [] do
          MapSet.new
      else
          [{_, set}] = :ets.lookup(:followersTable, username)
          set
      end

      mapSet = MapSet.put(mapSet, selfId)

      :ets.insert(:followersTable, {username, mapSet})

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

  def handle_in("registerMe", payload, socket) do
      username = Map.get(payload, "username")
      userIP = Map.get(payload, "userIP")

      register_status = :ets.insert_new(:userToIPMap, {username, userIP})       
      if register_status == false do
        spawn(fn -> GenServer.cast({String.to_atom(username), userIP},{:queryYourTweets}) end)
      end
      broadcast! socket, "registerMe", payload
      {:noreply, socket}
  end


   def handle_in("tweet", payload, socket) do
      username = Map.get(payload, "username")
      tweetBody = Map.get(payload, "tweetBody")

      {content, hashtags, mentions} = tweetBody

      # insert into tweetsDB get size - index / key. insert value mei tuple.
      Simulator.log("TweetID: #{nextID} => #{username} posted a new tweet : #{content}")
      # TweetID #{nextID} => 
      # index = Kernel.map_size(tweetsDB)
      spawn(fn->:ets.insert(:tweetsDB, {nextID, username, content})end)
      # tweetsDB = Map.put(tweetsDB, index, {username, content})
      spawn(fn -> updateMentionsMap(mentions, nextID) end)
      spawn(fn -> updateHashTagMap(hashtags, nextID) end)
      
      #broadcast 
      spawn(fn->sendToFollowers(MapSet.to_list(elem(List.first(:ets.lookup(:followersTable, username)), 1)), nextID, username, content) end)
      spawn(fn->sendToFollowers(mentions, nextID, username, content) end)

      broadcast! socket, "tweet", payload
      {:noreply, socket}
  end

  def handle_in("reTweet", payload, socket) do
      username = Map.get(payload, "username")
      tweetIndex = Map.get(payload, "tweetIndex")
      
      [{_, original_tweeter, content}] = :ets.lookup(:tweetsDB, tweetIndex)
      Simulator.log("TweetID: #{nextID} => #{username} posted a retweet of tweetID #{tweetIndex}")
      {org_tweeter, contentfinal} = 
      if is_tuple(content) do 
            {org_tweet, org_content} = content
            {org_tweet, org_content}
      else
            {original_tweeter, content}
      end
      
      # index = Kernel.map_size(tweetsDB)
      # tweetsDB = Map.put(tweetsDB, nextID, {username, {original_tweeter, content}})
      :ets.insert_new(:tweetsDB, {nextID, username, {org_tweeter, contentfinal}})

      #mentionsMap = updateMentionsMap(mentionsMap, mentions, index)
      #hashtagMap = updateHashTagMap(hashtagMap, hashtags, index)
    #   IO.inspect tweetsDB
      #broadcast 
      spawn(fn -> sendToFollowers(MapSet.to_list(elem(List.first(:ets.lookup(:followersTable, username)), 1)), nextID, username, {original_tweeter, content})end)
      
      broadcast! socket, "reTweet", payload
      {:noreply, socket}
  end

  def handle_in("myMentions", payload, socket) do
      username = Map.get(payload, "username")
      mentions =
      if :ets.lookup(:mentionsMap, username) == [] do
        MapSet.new
      else
        [{_, set}] = :ets.lookup(:mentionsMap, username)
        set
      end
      mentionedTweets = getMentions(MapSet.to_list(mentions), [])
      spawn(fn -> GenServer.cast({String.to_atom(username), elem(List.first(:ets.lookup(:userToIPMap, username)), 1)},{:receiveMyMentions, mentionedTweets}) end)
      broadcast! socket, "myMentions", payload
      {:noreply, socket}
  end

   def handle_in("tweetsWithHashtag", payload, socket) do
      username = Map.get(payload, "username")
      hashtag = Map.get(payload, "hashtag")

      tweets = 
      if :ets.lookup(:hashtagMap, hashtag) == [] do
        MapSet.new
      else
        [{_, set}] = :ets.lookup(:hashtagMap, hashtag)
        set
      end

      hashtagTweets = getHashtags(MapSet.to_list(tweets), [])
      spawn(fn -> GenServer.cast({String.to_atom(username), elem(List.first(:ets.lookup(:userToIPMap, username)), 1)},{:receiveHashtagResults, hashtagTweets}) end)
      broadcast! socket, "tweetsWithHashtag", payload
      {:noreply, socket}
  end

  def handle_in("queryTweets", payload, socket) do
      username = Map.get(payload, "username")
      
      mapSet = 
      if :ets.lookup(:followsTable,username) == [] do
        MapSet.new
      else
        [{_, set}] = :ets.lookup(:followsTable,username)
        set
      end 
      relevantTweets = fetchRelevantTweets(mapSet)

      mentions = 
      if :ets.lookup(:mentionsMap,username) == [] do
        MapSet.new
      else 
        [{_, set}] = :ets.lookup(:mentionsMap,username)
        set
      end

      mentionedTweets = getMentions(MapSet.to_list(mentions), [])
      spawn(fn -> GenServer.cast({String.to_atom(username), elem(List.first(:ets.lookup(:userToIPMap, username)), 1)},{:receiveQueryResults, relevantTweets, mentionedTweets}) end)
      broadcast! socket, "queryTweets", payload
      {:noreply, socket}
      
  end
  
    
  def fetchRelevantTweets(mapSet) do
      result = 
      for f_user <- MapSet.to_list(mapSet) do
        list_of_tweets = List.flatten(:ets.match(:tweetsDB, {:_, f_user, :"$1"}))
        Enum.map(list_of_tweets, fn tweet -> {f_user, tweet} end)
    end
    List.flatten(result)
  end

  def sendToFollowers([first | followers], index, username, content) do
      spawn(fn->GenServer.cast({String.to_atom(first), elem(List.first(:ets.lookup(:userToIPMap, first)), 1)},{:receiveTweet, index, username, content})end) 
      # spawn(fn->GenServer.cast(String.to_atom(first),{:receiveTweet, index, username, content})end) 

      sendToFollowers(followers, index, username, content)
  end
  
  def sendToFollowers([], _, _, _) do
  end

  def getHashtags([index | rest], hashtagTweets) do
      [{index, username, content}] = :ets.lookup(:tweetsDB, index)
      hashtagTweets = List.insert_at(hashtagTweets, 0, {index, {username, content}})
      getHashtags(rest, hashtagTweets)
  end

  def getHashtags([], hashtagTweets) do
      hashtagTweets
  end

  def getMentions([index | rest], mentionedTweets) do
      [{index, username, content}] = :ets.lookup(:tweetsDB, index)
      mentionedTweets = List.insert_at(mentionedTweets, 0, {index, {username, content}})
      getMentions(rest, mentionedTweets)
  end

  def getMentions(_, [], mentionedTweets) do
    mentionedTweets
  end

  def updateMentionsMap([mention | mentions], index) do
      elems = 
      if :ets.lookup(:mentionsMap, mention) == [] do
          element = MapSet.new
          MapSet.put(element, index)
      else
          [{_,element}] = :ets.lookup(:mentionsMap, mention)
        MapSet.put(element, index)
      end

      :ets.insert(:mentionsMap, {mention, elems})
      updateMentionsMap(mentions, index)
  end

  def updateMentionsMap([], _) do
  end

  def updateHashTagMap([hashtag | hashtags], index) do
      elems = 
      if :ets.lookup(:hashtagMap, hashtag) == [] do
          element = MapSet.new
          MapSet.put(element, index)
      else
          [{_,element}] = :ets.lookup(:hashtagMap, hashtag)
          MapSet.put(element, index)
      end

      :ets.insert(:hashtagMap, {hashtag, elems})
      updateHashTagMap(hashtags, index)
  end

  def updateHashTagMap([], _) do
  end

  # Returns the IP address of the machine the code is being run on.
  def findIP(iter) do
    list = Enum.at(:inet.getif() |> Tuple.to_list, 1)
    if (elem(Enum.at(list, iter), 0) == {127, 0, 0, 1}) do
      findIP(iter+1)
    else
      elem(Enum.at(list, iter), 0) |> Tuple.to_list |> Enum.join(".")
    end
  end

end


  







end