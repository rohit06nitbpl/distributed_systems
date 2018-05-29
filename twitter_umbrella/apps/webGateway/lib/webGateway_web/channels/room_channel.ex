defmodule WebGatewayWeb.RoomChannel do
    use Phoenix.Channel
  
    def join("user:lobby", _message, socket) do
      {:ok, socket}
    end
    def join("user:"<>user_id, params, socket) do
        %{"params" => token} = params
        %{"token" => token } = token
        #max_age: 1209600 is equivalent to two weeks in seconds
        case Phoenix.Token.verify(socket, "user socket", token, max_age: 1209600) do
            {:ok, user_id} ->
            
            {:ok, assign(socket, :current_user, user_id)}
            {:error, reason} ->
            :error
        end
        {:ok, socket}
    end

    def handle_in("get_homepage", %{"username" => username}, socket) do
        case lookup username , fn pid -> Worker.Proc.cast_homepage(pid, username) end do

            {:error, :user_not_found} -> IO.puts "get_homepage: #{username} not found" 
            _ -> :ok
        end
        {:noreply, socket}
    end

    def handle_in("tweet", %{"msg" => msg} , socket) do
        IO.puts "comes in tweet"
        IO.inspect msg
        %{"username" => username, "tweet" => tweet} = msg
        tweet = String.split(tweet)
        case lookup username , fn pid -> Worker.Proc.tweet(pid, username, tweet) end do
            
            {:error, :user_not_found} -> IO.puts "tweet: #{username} not found" 
            _ -> :ok
        end
        {:noreply, socket}
    end

    def handle_in("retweet", %{"params" => params}, socket) do
        IO.puts "comes in retweet"
        %{"username" => username, "retweet" => twt_id} = params
        
        case lookup username , fn pid -> Worker.Proc.retweet(pid, username, twt_id) end do
            
            {:error, :user_not_found} -> IO.puts "retweet: #{username} not found" 
            _ -> :ok
        end
        {:noreply, socket}
    end

    def handle_in("follow", %{"msg" => params}, socket) do
        IO.puts "comes in follow"
        %{"username" => username, "user_to_follow" => users_to_follow} = params
        
        case lookup username , fn pid -> Worker.Proc.follow(pid, username, [users_to_follow]) end do
            
            {:error, :user_not_found} -> IO.puts "follow: #{username} not found" 
            _ -> :ok
        end
        {:noreply, socket}
    end

    def handle_in("search", %{"msg" => params}, socket) do
        IO.puts "comes in search"
        %{"username" => username, "search_query" => hashtag} = params
        
        case lookup username , fn pid -> Worker.Proc.search(pid, username, hashtag) end do
            
            {:error, :user_not_found} -> IO.puts "search: #{username} not found" 
            _ -> :ok
        end
        {:noreply, socket}
    end


    

    ## PRIVATE METTHOD
    defp lookup(username, callback) do
        case Worker.Registry.lookup_proc(Worker.Registry, username) do
        {:ok, pid} -> callback.(pid)
        :error -> {:error, :user_not_found}
        end
    end
end