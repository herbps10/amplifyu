player = {
  socket: null,
  status: "",
  mode: "player",

  onopen: function() {
  },
  
  /************************
   * MESSAGES FROM SERVER *
   ************************/
  onmessage: function(e) {
    data = eval('(' + e.data + ')');

    /************
     * POSITION *
     ************/

    if(data.action == "position") {
      if(player.seeker.sliding == false) {
        player.seeker.value = ((parseFloat(data.value) * 100) / player.current.duration) * 10;

        player.seeker.display();
      }
    }


    /***********
     * STARTUP *
     ***********/

    else if(data.action == "startup") {
      if(data.status == "playing") {
        player.current.name     = data.name;
        player.current.artist   = data.artist;
        player.current.id       = data.id;
        player.current.duration = parseFloat(data.duration);
        player.seeker.value     = (parseFloat(data.position) * 100) / parseFloat(data.duration);

        player.current.fade_in_time   = parseFloat(data.fade_in_time);
        player.current.fade_out_time  = parseFloat(data.fade_out_time);

        player.current.fade_type = data.fade_type;

        console.log(data);

        $("#volume").slider('values', data.volume);

        player.onPlay(); 
        player.current.display();
      }
    }
    
    /*********
     * PAUSE *
     *********/

    else if(data.action == "pause") {
      player.onPause();
    }

    
    /********
     * PLAY *
     ********/

    else if(data.action == "play") {
      player.onPlay();
    }


    /**********
     * VOLUME *
     **********/

    else if(data.action == "volume") {
      $("#volume").slider('value', data.value);
    }


    /********
     * LOAD *
     ********/

    else if(data.action == "load") {
      player.current.id     = data.id;
      player.current.name   = data.name;
      player.current.artist = data.artist;
      player.current.duration = parseFloat(data.duration);

      player.current.fade_in_time = parseFloat(data.fade_in_time)
      player.current.fade_out_time = parseFloat(data.fade_out_time)

      player.onPlay();

      player.seeker.reset();

      player.current.display();
    }
  },

  /*
   * UPDATE STATUS
   *
   */
  updateStatus: function(callback) {
    $.getJSON('/status.json', function(data) {
      player.status = data.status;

      if(callback) callback();
    });
  },


  /********************************
   * SEND VOLUME CHANGE TO SERVER *
   ********************************/

  volume: function(value) {
    if(player.socket == null) {
      // TODO: Fixme
    }
    else {
      player.socket.send('{"action": "volume", "value": ' + value + '}');
    }
  },

  
  /************
   * SET FADE *
   ************/

  set_fade: function(type, value, track, playlist) {
    if((typeof track) == 'undefined' && (typeof playlist == 'undefined')) {
      if(type == 'fade_in') {
        player.socket.send('{"action": "fade_in_time", "value": ' + value + '}');
      }
      else if(type == 'fade_out') {
        player.socket.send('{"action": "fade_out_time", "value": ' + value + '}');
      }
    }
    else {
      if(type == 'fade_in') {
        player.socket.send('{"action": "fade_in_time", "value": ' + value + ', "track": ' + track + ', "playlist": ' + playlist + '}');
      }
      else if(type == 'fade_out') {
        player.socket.send('{"action": "fade_out_time", "value": ' + value + ', "track": ' + track + ', "playlist": ' + playlist + '}');
      }
    }
  },

  set_fade_type: function(type, track, playlist) {
    if((typeof track) !== 'undefined' && (typeof playlist) !== 'undefined') {
      player.socket.send('{"action": "fade_type", "value": ' + type + ', "track": ' + track + ', "playlist": ' + playlist + '}');
    }
    else {
      console.log("Sending type: " + type);
      player.socket.send('{"action": "fade_type", "value": ' + type + '}');
    }
  },


  /*
   * PLAY
   *
   */
  play: function() {
    if(player.socket == null) {
      $.get("/play");
    }
    else {
      player.socket.send('{"action": "play"}');
    }

    player.onPlay();
  },

  /*
   * PAUSE
   *
   */
  pause: function() {
    if(player.socket == null) {
      $.get("/pause");
    }
    else {
      player.socket.send('{"action": "pause"}');
    }

    player.onPause();
  },

  
  /*
   * SEEK
   *
   */
  seek: function(value) {
    player.seeker.value = value;

    if(player.socket == null) {
      $.get("/seek/" + value);
    }
    else {
      console.log("Sending " + value );
      player.socket.send('{"action": "seek", "value": ' + value + '}');
    }
  },


  /*
   * LOAD
   *
   */
  load: function(value) {
    if(player.socket == null) {
      $.get("/load/" + value, function() {
        player.onPlay();
        player.current.update();
      });
    }
    else {
      player.socket.send('{"action": "load", "value": ' + value + '}');
    }

    player.seeker.reset();
    
    player.onPlay();
  },

  display_track: function(track, playlist) {
    $.getJSON('/track_playlist_info.json', { 
      track: track,
      playlist: playlist
    }, function(data) {
      player.current.id       = data.track.id;
      player.current.name     = data.track.name;
      player.current.duration = data.track.duration;
      player.current.artist   = data.track.artist;

      player.current.fade_in_time   = data.track.fade_in_time;
      player.current.fade_out_time  = data.track.fade_out_time;
      player.current.fade_type      = data.track.fade_type;

      player.current.display();
    });
  },

  stop: function() {
    if(player.socket == null) {
      $.get("stop");
    }
    else {
      player.socket.send('{"action": "stop"}');
    }
  },

  current: {
    name: "",
    duration: 0,
    artist: "",

    update: function(callback) {
      $.getJSON('/track.json', function(data) {
        if(data.status == "loaded" || data.status == "playing" || data.status == "paused") {
          player.status = "loaded";

          player.current.name     = data.track.name;
          player.current.duration = data.track.duration;
          player.current.artist   = data.track.artist;

          player.current.display();

          if(callback) {
            callback();
          }
        }
        else {
          player.status = "stopped";
        }
      });
    },

    display: function() {
      $(".artist").text(player.current.artist);
      $(".track").text(player.current.name);

      $("#seeker").css('background', 'url(/waveforms/' + player.current.id + '.png)');

      console.log(player.current.fade_out_time)
      console.log(player.current.fade_in_time)
      console.log(player.current.fade_type)

      if(player.current.fade_out_time) {
        if(player.current.fade_out_time == -1) {
          right_width = 0;
          $("#seeker").slider('values', 2, 1000);
        }
        else {
          var right_value = (player.current.fade_out_time * 1000) / player.current.duration;
          var right_width = 700 - (player.current.fade_out_time * 700) / player.current.duration + 10;
        }

        // Update the fader values
        $(".right-fader").width(right_width + "px");
        $("#seeker").slider("values", 2, right_value);

      }
      
      if(player.current.fade_type >= 0)
        $(".transition").val(player.current.fade_type);

      if(player.current.fade_in_time) {
        if(player.current.fade_in_time == -1) {
          left_width = 0;
          $("#seeker").slider('values', 0, 0);
        }
        else {
          var left_value = (player.current.fade_in_time * 1000) / player.current.duration;
          var left_width = (player.current.fade_in_time * 700) / player.current.duration - 10;

          if(left_width < 0) left_width = 0;
        }

        $(".left-fader").width(left_width + "px");
        $("#seeker").slider("values", 0, left_value);
      }


      $.getJSON('/sections.json?track_id=' + player.current.id, function(segments) {
        $("#seeker .segment").remove();
        $.each(segments, function(index, segment) {
          var percentage = (parseFloat(segment.section.start) * 100) / player.current.duration;

          $("#seeker").append("<div class='segment' style='left: " + percentage + "%'></div>");
        });
      });
    }
  },

  library: {
    tracks: [],

    update: function(callback) {
      if(window.library) {
        player.library.tracks = window.library.tracks; // This variable is populated in page load from Sinatra and saved in window so we can grab it here

        player.library.display();
      }

      //if(callback) callback();
    },

    display: function() {
      $.getJSON("/playlists.json", function(data) {
        var playlist_template = "<select class='playlist'>";

        $.each(data, function(index, playlist) {
          playlist_template += "<option value='" + playlist.playlist.id + "'>" + playlist.playlist.name + "</option>";
        });

        playlist_template += "</select>";
        playlist_template += "<button class='add'>add</button>";


        for(var index = 0; index < player.library.tracks.length; index++) {
          var track = player.library.tracks[index];

          $(".tracks").append('<tr data-id="' + track.id + '"><td>' + track.name + '</td><td>' + track.artist + '</td><td>' + track.genre + '</td><td><a class="play" href="#" rel="' + index + '">play</a></td><td>' + playlist_template + '</td></tr>');
        }

      })
    }
  },

  onPlay: function() {
    $("#control").text("Pause");
    $("#control").removeClass('play').addClass('pause');

    player.status = "playing";
  },

  onPause: function() {
    $("#control").text("Play");
    $("#control").removeClass('pause').addClass('play');

    player.status = "paused";
  },

  seeker: {
    value: 0,
    interval: null,
    sliding: false,

    update: function() {
      player.seeker.value = player.seeker.value +(100 / player.current.duration);

      player.seeker.display();
    },

    display: function() {
      if(player.seeker.sliding == false) {
        $("#seeker").slider('values', 1, player.seeker.value);
      }
    },
    
    reset: function() {
      player.seeker.value = 0;
      
      player.seeker.display();
    }
  }
}
