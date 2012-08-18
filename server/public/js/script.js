//
// Herb Susmann
// Summer 2012
//
// Feel free to email me with any questions
// herbps10@gmail.com
//

var ip = "192.168.1.2"

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

  $(".transition").change(function() {
    player.set_fade_type($(this).val());
  });

  $("#seeker a").append("<a class='slider-target'></a>");

  $("#seeker a.ui-slider-handle").filter(":first").addClass("fader");
  $("#seeker a.ui-slider-handle").filter(":last").addClass("fader");

  $(".add").live('click', function() {
    var track_id = $(this).parent().parent().attr('data-id');
    var playlist_id  = $(this).siblings("select").children("option:selected").val();

    $.get("add_track_to_playlist?track=" + track_id + "&playlist=" + playlist_id);
    //window.location = "/add_track_to_playlist?track=" + track_id + "&playlist=" + playlist_id;
  });
});
