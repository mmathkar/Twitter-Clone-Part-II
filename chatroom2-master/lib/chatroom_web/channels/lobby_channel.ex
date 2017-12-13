defmodule Chatroom.LobbyChannel do
    use Phoenix.Channel
  
    def join("lobby", _payload, socket) do
      {:ok, socket}
    end

    def handle_in("register_account", payload, socket) do
        user_name = payload["username"]
        password = payload["password"]
        current_time = DateTime.utc_now()
        register_success = :ets.insert_new(:users, {user_name, password, current_time})
        {:noreply, socket}
    end

    def handle_in("login", payload, socket) do
        user_name = payload["username"]
        password = payload["password"]
        current_time = DateTime.utc_now()
        login_pwd = if :ets.lookup(:users, user_name) != [] do
            elem(List.first(:ets.lookup(:users, user_name)), 1)
        else
            ""
        end
        
        if login_pwd == password do
            :ets.insert(:map_of_sockets, {user_name, socket})
            push socket, "Login", %{login_status: "Login successful" , user_name: user_name }
        else 
            push socket, "Login", %{login_status: "Login unsuccessful" , user_name: user_name}
        end
        {:noreply, socket}
    end

    def handle_in("update_socket", payload, socket) do
        username = Map.get(payload, "username")
        :ets.insert(:map_of_sockets, {username, socket})
        {:noreply, socket}
    end

    def handle_in("subscribeTo", payload, socket) do
        username = Map.get(payload, "username2")
        selfId = Map.get(payload, "selfId")
        :ets.insert(:map_of_sockets, {selfId, socket})
        
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
    
        # broadcast! socket, "subscribeTo", payload
        {:noreply, socket}
      end

      def handle_in("reTweet", payload, socket) do
        IO.inspect "REACHED HERE"
        nextID = :ets.info(:tweetsDB)[:size]

        username = Map.get(payload, "username")
        content = Map.get(payload, "tweet")
        org_user = Map.get(payload, "org")

        :ets.insert(:map_of_sockets, {username, socket})
        {hashtags, mentions} = extractMentionsAndHashtags(content)
 
        :ets.insert(:tweetsDB, {nextID, username, content, true, org_user})

        updateMentionsMap(mentions, nextID)
        updateHashTagMap(hashtags, nextID)
        
        #broadcast 
        followers = 
        if List.first(:ets.lookup(:followersTable, username)) == nil do
            []
        else
            MapSet.to_list(elem(List.first(:ets.lookup(:followersTable, username)), 1))
        end

        payload2 = %{tweeter: username, tweetText: content, isRetweet: true, org: org_user}
        IO.inspect payload2
        sendToFollowers(followers, nextID, username, payload2)
        sendToFollowers(mentions, nextID, username, payload2)
        {:noreply, socket}
    end

    # def parseContent(content) do
    #     map = Regex.named_captures(~r/(?<tweeter>[a-z|A-Z|\d]+) tweeted: (?<text>[a-z|A-Z| |@|#|\d]*)/, content)
    #     {Map.get(map,"text"), Map.get(map,"tweeter")}
    # end

      def handle_in("getMyMentions", payload, socket) do
        username = Map.get(payload, "username")
        mentions =
        if :ets.lookup(:mentionsMap, username) == [] do
          MapSet.new
        else
          [{_, set}] = :ets.lookup(:mentionsMap, username)
          set
        end
        mentionedTweets = getMentions(MapSet.to_list(mentions), [])
        push socket, "ReceiveMentions", %{tweets: mentionedTweets}
        {:noreply, socket}
    end

    def getMentions([index | rest], mentionedTweets) do
        [{index, username, content, isRetweet, org_tweeter}] = :ets.lookup(:tweetsDB, index)
        # mentionedTweets = List.insert_at(mentionedTweets, 0, {index, {username, content}})
        mentionedTweets = List.insert_at(mentionedTweets, 0, %{tweetID: index, tweeter: username, tweet: content, isRetweet: isRetweet, org: org_tweeter})
        getMentions(rest, mentionedTweets)
    end
  
    def getMentions([], mentionedTweets) do
      IO.inspect mentionedTweets
    end

    def handle_in("tweetsWithHashtag", payload, socket) do
        hashtag = Map.get(payload, "hashtag")
  
        tweets = 
        if :ets.lookup(:hashtagMap, hashtag) == [] do
          MapSet.new
        else
          [{_, set}] = :ets.lookup(:hashtagMap, hashtag)
          set
        end
  
        hashtagTweets = getHashtags(MapSet.to_list(tweets), [])
        push socket, "ReceiveHashtags", %{tweets: hashtagTweets}
        {:noreply, socket}
    end

    def getHashtags([index | rest], hashtagTweets) do
        [{index, username, content, isRetweet, org_tweeter}] = :ets.lookup(:tweetsDB, index)
        hashtagTweets = List.insert_at(hashtagTweets, 0, %{tweetID: index, tweeter: username, tweet: content, isRetweet: isRetweet, org: org_tweeter})
        getHashtags(rest, hashtagTweets)
    end
  
    def getHashtags([], hashtagTweets) do
        hashtagTweets
    end

      def handle_in("tweet", payload, socket) do
        username = Map.get(payload, "username")
        content = Map.get(payload, "tweetText")
        :ets.insert(:map_of_sockets, {username, socket})
        {hashtags, mentions} = extractMentionsAndHashtags(content)
        nextID = :ets.info(:tweetsDB)[:size]
        # insert into tweetsDB get size - index / key. insert value mei tuple.
        # Simulator.log("TweetID: #{nextID} => #{username} posted a new tweet : #{content}")
        # TweetID #{nextID} => 
        # index = Kernel.map_size(tweetsDB)
        :ets.insert(:tweetsDB, {nextID, username, content, false, nil})
        # tweetsDB = Map.put(tweetsDB, index, {username, content})
        updateMentionsMap(mentions, nextID)
        updateHashTagMap(hashtags, nextID)
        
        #broadcast 
        followers = 
        if List.first(:ets.lookup(:followersTable, username)) == nil do
            []
        else
            MapSet.to_list(elem(List.first(:ets.lookup(:followersTable, username)), 1))
        end
        payload2 = %{tweeter: username, tweetText: content, isRetweet: false, org: nil}
        sendToFollowers(followers, nextID, username, payload2)
        sendToFollowers(mentions, nextID, username, payload2)
  
        # broadcast! socket, "tweet", payload
        # IO.inspect socket
        # broadcast! socket, "ReceiveTweet", payload
        {:noreply, socket}
    end

    def extractMentionsAndHashtags(content) do
        split_words=String.split(content," ")
        hashtags=findHashTags(split_words,[])
        mentions=findMentions(split_words,[])
        {hashtags, mentions}
    end

    def findHashTags([head|tail],hashList) do
        if(String.first(head)=="#") do
          [_, elem] = String.split(head, "#") 
          findHashTags(tail,List.insert_at(hashList, 0, head))
        else 
          findHashTags(tail,hashList)
        end
    
      end
    
      def findHashTags([],hashList) do
        hashList
      end
    
      def findMentions([head|tail],mentionList) do
        if(String.first(head)=="@") do
          [_, elem] = String.split(head, "@") 
          findMentions(tail,List.insert_at(mentionList, 0, elem))
          
        else 
          findMentions(tail,mentionList)
        end
    
      end
    
      def findMentions([],mentionList) do
        mentionList
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
        IO.inspect hashtag
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

    def sendToFollowers([first | followers], index, username, payload) do
        push elem(List.first(:ets.lookup(:map_of_sockets, first)), 1),  "ReceiveTweet", payload
        sendToFollowers(followers, index, username, payload)
    end
    
    def sendToFollowers([], _, _, _) do
    end
    # :ets.insert(:map_of_sockets, {socket.id, socket})
    # list_of_socket_ids = ["Roukna"]
    #for s_id <- list_of_socket_ids do
    #    s_val = elem(List.first(:ets.lookup(:map_of_sockets, s_id)), 1)
    #    push s_val, "Registered", payload
    #end

    #IO.inspect user_name
    #IO.inspect password
    #IO.inspect register_success

    #def handle_in("login", payload, socket) do
    #    user_name = payload["name"]
    #    password = payload["message"]
    #    current_time = DateTime.utc_now()
        
    #    login_pwd = elem(List.first(:ets.lookup(:users, user_name)), 1)
    #    if login_pwd == password do
    #        :ets.insert(:map_of_sockets, {user_name, socket})
    #    else 
    #      {:noreply, state}
    #    end

    #    register_success = :ets.insert_new(:users, {user_name, password, current_time})
    #    :ets.insert(:map_of_sockets, {socket.id, socket})

    #    list_of_socket_ids = ["Roukna"]
    #    for s_id <- list_of_socket_ids do
    #        s_val = elem(List.first(:ets.lookup(:map_of_sockets, s_id)), 1)
    #        push s_val, "Registered", payload
    #    end
        #IO.inspect user_name
        #IO.inspect password
        #IO.inspect register_success
    #    {:noreply, socket}
    #end



  end