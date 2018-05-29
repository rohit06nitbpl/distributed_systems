
import {Socket} from 'phoenix'


class User {
    constructor (userName) {
        this.userName = userName
        
    }

    connect_websocket() {
        // Set up the websocket connection
        this.socket = new Socket('/socket', {params: {token: window.userToken}})
        this.socket.connect()
        let lobby_channel = this.socket.channel("user:lobby", {})
        lobby_channel.join()
          .receive("ok", resp => { console.log("lobby Joined successfully", resp) })
          .receive("error", resp => { console.log("Unable to join", resp) })
        let topic =  "user:" + String(this.userName)
        this.channel = this.socket.channel(topic, {params: {token: window.userToken}})
        this.channel.join()
          .receive("ok", resp => { console.log("username Joined successfully", resp) })
          .receive("error", resp => { console.log("Unable to join", resp) })
        
        this.channel.push("get_homepage", {username: this.userName})

        this.channel.on("n_follower", payload => {
          document.getElementById("n_follower").innerHTML = payload.count
        
        })

        

        this.channel.on("time_line", payload => {
          var time_line = document.getElementById("timeline")
          for (var i = 0; i < payload.timeline.length; i++) { 
            //var tweet_box = document.createElement("DIV");
            var twt = document.createElement("DIV");
            twt.style.margin = "15px"
            var _twt_id = payload.timeline[i].twt_id
            var _p_twt_id = payload.timeline[i].p_twt_id
            var _twt_body = payload.timeline[i].body
            var twt_l = _twt_id.split("-")
            var twt_user = twt_l[0]
            var twt_timestamp = twt_l[1]
            twt.setAttribute("class", "tweet js-stream-tweet js-actionable-tweet js-profile-popup-actionable dismissible-content original-tweet js-original-tweet tweet-has-context has-cards dismissible-content has-content")
            twt.setAttribute("twt_id", _twt_id)
            twt.setAttribute("p_twt_id", _p_twt_id)

            //var twt_usr_html = document.createElement("B");
            //twt_usr_html.innerHTML = "@"+twt_user;
            //twt.appendChild(twt_usr_html)
            var user_str = "@"+twt_user;
            //user_str = user_str.bold();

            twt.innerText = user_str + " : "+_twt_body
            //console.log(twt.innerText)
            


            //var form = document.createElement("FORM");
            //form.setAttribute("method", "POST");
            //form.setAttribute("action","/retweet");

            var form_span = document.createElement("SPAN");
            var input_button = document.createElement("INPUT");
            input_button.setAttribute("type","submit")
            input_button.setAttribute("class", "EdgeButton EdgeButton--primary EdgeButton--medium submit js-submit")
            input_button.setAttribute("value","ReTweet")
            
            
            

            if (_twt_id.split("-")[0] != this.userName) {
              if ( _p_twt_id.split("-")[0] != this.userName || _p_twt_id.split("-")[0] == "-1") {
              
              let user = this.userName
              let channel = this.channel
              input_button.onclick = function () {
                var _params = {username: user, retweet: _twt_id}
                channel.push("retweet", {params: _params})
              }
            }

            } else {
              input_button.disabled = true;
            }
             
            form_span.appendChild(input_button)
            twt.appendChild(form_span)

            time_line.appendChild(twt)
          }
        })
        
        let user = this.userName
        let channel = this.channel
        let send_tweet = document.getElementById("send_tweet").onclick = function() {
          //console.log("asdf asdf")
          var msg = {username: user, tweet: document.getElementById("tweet-box-home-timeline").value}
          //console.log(msg)
          document.getElementById("tweet-box-home-timeline").value = ""
          channel.push("tweet", {msg: msg} )
        }

        let follow_user = document.getElementById("follow_user").onclick = function() {

          var msg = {username: user, user_to_follow: document.getElementById("user_to_follow").value}
          document.getElementById("user_to_follow").value = ""
          channel.push("follow", {msg: msg} )
        }

        /*let search_query = document.getElementById("search-hit").onclick = function() {
          var msg = {username: user, search_query: document.getElementById("search-query").value}
          document.getElementById("search-query").value = ""
          channel.push("search", {msg: msg} )
        }*/


        /*this.channel.on("search_result", payload => {
          var search_result = document.getElementById("search_result")
          console.log(payload.result)
          var result = payload.result.split("\r\n")
          for (var i = 0; i < result.length; i++) { 
            var srch = document.createElement("DIV");
            srch.style.margin = "15px"
            srch.setAttribute("class", "tweet js-stream-tweet js-actionable-tweet js-profile-popup-actionable dismissible-content original-tweet js-original-tweet tweet-has-context has-cards dismissible-content has-content")
            srch.innerText = result[i]
            search_result.appendChild(srch)
          }

        })*/

        


      
    }

    populate_search() {
      
      let search_query = document.getElementById("search-hit").onclick = function() {
        var msg = {username: user, search_query: document.getElementById("search-query").value}
        document.getElementById("search-query").value = ""
        channel.push("search", {msg: msg} )
      }

      this.channel.on("search_result", payload => {
        var search_result = document.getElementById("search_result")
        console.log(payload.result)
        var result = payload.result.split("\r\n")
        for (var i = 0; i < result.length; i++) { 
          var srch = document.createElement("DIV");
          srch.style.margin = "15px"
          srch.setAttribute("class", "tweet js-stream-tweet js-actionable-tweet js-profile-popup-actionable dismissible-content original-tweet js-original-tweet tweet-has-context has-cards dismissible-content has-content")
          srch.innerText = result[i]
          search_result.appendChild(srch)
        }

      })

    }

    
    
}

let App = {
    connect_ws: function(){
      var userName = document.getElementById("username").innerHTML;
      userName = userName.slice(1);
      var user = new User(userName)
      user.connect_websocket()

      //var send_tweet = document.getElementById("send_tweet")
      //send_tweet.onclick = user.handle_tweet(user.channel)
    },
    anotherPage: function(data){
      var userName = document.getElementById("username").innerHTML;
      userName = userName.slice(1);
      var user = new User(userName)
      user. populate_search()
    }
  };

  // Look for any onload messages, give it the App
// context
if(window.appConfig !== undefined) {
    window.appConfig.onLoad.call(this, App);
}
  
//export default socket