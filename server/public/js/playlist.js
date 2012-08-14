var ip = "192.168.1.4"

// from http://www.netlobo.com/url_query_string_javascript.html
function url_parameter(name)
{
  name = name.replace(/[\[]/,"\\\[").replace(/[\]]/,"\\\]");
  var regexS = "[\\?&]"+name+"=([^&#]*)";
  var regex = new RegExp( regexS );
  var results = regex.exec( window.location.href );
  if( results == null )
    return "";
  else
    return results[1];
}

$(document).ready(function() {
  player.socket = new WebSocket("ws://" + ip + ":5000");
  //player.socket.onmessage = player.onmessage;
  //player.socket.onopen = player.onopen;

  var track_id = url_parameter('track');
  var playlist_id = url_parameter('playlist');

  player.display_track(track_id, playlist_id);

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

        player.set_fade('fade_in', fade_in_time, url_parameter('track'), url_parameter('playlist'));

        $(".left-fader").css('width', width);
      }
      // Right fader slider
      else if($(ui.handle).index() == 3) {
        value = $("#seeker").slider('values', 2);
        
        width = 700 - (value * 700) / 1000 + 10;
        $(".right-fader").css('width', width);

        var fade_out_time = (value * player.current.duration) / 1000;

        player.set_fade('fade_out', fade_out_time, url_parameter('track'), url_parameter('playlist'));
      }
    }
  });

  $("#seeker a").append("<a class='slider-target'></a>");

  $("#seeker a.ui-slider-handle").filter(":first").addClass("fader");
  $("#seeker a.ui-slider-handle").filter(":last").addClass("fader");

  $("#seeker > a").not(".fader").remove();

  $(".transition").change(function() {
    player.set_fade_type($(this).val(), url_parameter('track'), url_parameter('playlist'));
  });
});
