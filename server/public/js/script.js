//
// Herb Susmann
// Summer 2012
//
// Feel free to email me with any questions/yell at me for bad code
// herbps10@gmail.com
//

var ip = "192.168.1.4"

player = {
  socket: null,
  status: "",

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

  set_fade: function(type, value) {
    if(type == 'fade_in') {
      player.socket.send('{"action": "fade_in_time", "value": ' + value + '}');
    }
    else if(type == 'fade_out') {
      player.socket.send('{"action": "fade_out_time", "value": ' + value + '}');
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
      player.library.tracks = window.library.tracks; // This variable is populated in page load from Sinatra and saved in window so we can grab it here

      player.library.display();

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

$(document).ready(function() {
  player.socket = new WebSocket("ws://" + ip + ":5000");
  player.socket.onmessage = player.onmessage;
  player.socket.onopen = player.onopen;

  player.library.update();

  /******************
   * Load new track *
   ******************/

  $(".tracks a.play").live('click', function() {
    var track = player.library.tracks[parseInt($(this).attr('rel'))];

    player.current.id       = track.id;
    player.current.name     = track.name;
    player.current.artist   = track.artist;
    player.current.duration = parseFloat(track.duration);

    player.current.display();
    
    player.load(track.id);
    
    return false;
  });


  /*********************
   * Play button event *
   *********************/

  $("#controls .play").live('click', function() {
    player.play();

    return false;
  });

  /**********************
   * Pause button event *
   **********************/

  $(".pause").live('click', function() {
    player.pause();

    return false;
  });


  /*****************
   * Volume slider *
   *****************/

  $("#volume").slider({
    orientation: "vertical",

    slide: function(event, ui) {
      var value = ui.value;

      player.volume(value);
    }
  });

  $(".add-playlist input[type=submit]").click(function() {
    var name = $(".add-playlist input[type=text]").val();
    $.get("/playlist/add/" + name, function(data) {
    
    });
    return false;
  });


  /***************
   * Seek slider *
   ***************/

  $("#seeker").slider({
    min: 0,
    max: 1000,
    values: [0, 0, 1000],
    slide: function(event, ui) {
      var value, width;

      // Left fader slider
      if($(ui.handle).index() == 2) {
        value = $("#seeker").slider('values', 0);
        width = (value * 700) / 1000 - 10;

        var fade_in_time = (value * player.current.duration) / 1000;

        player.set_fade('fade_in', fade_in_time);

        $(".left-fader").css('width', width);
      }
      // Right fader slider
      else if($(ui.handle).index() == 4) {
        value = $("#seeker").slider('values', 2);
        
        width = 700 - (value * 700) / 1000 + 10;
        $(".right-fader").css('width', width);

        var fade_out_time = (value * player.current.duration) / 1000;

        player.set_fade('fade_out', fade_out_time);
      }
    },

    start: function() {
      player.seeker.sliding = true;
    },

    stop: function(event, ui) {
      player.seeker.sliding = false;
      // Seeker slider
      if($(ui.handle).index() == 3) {
        value = $("#seeker").slider('values', 1);
        var seconds = ((value / 10) * player.current.duration) / 100;

        player.seek(seconds);
      }
    }
  });

  $("a.play_from_playlist").click(function() {
    $.get($(this).attr('href'));
    return false;
  });

  $("#seeker a").append("<a class='slider-target'></a>");

  $("#seeker a.ui-slider-handle").filter(":first").addClass("fader");
  $("#seeker a.ui-slider-handle").filter(":last").addClass("fader");

  $(".add").live('click', function() {
    var track_id = $(this).parent().parent().attr('data-id');
    var playlist_id  = $(this).siblings("select").children("option:selected").val();

    $.get("add_track_to_playlist?track=" + track_id + "&playlist=" + playlist_id);
  });
});
