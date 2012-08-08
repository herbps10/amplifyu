var App = Em.Application.create({
  ready: function() {
    // Load playlists from JSON

    $.getJSON("/playlists.json", function(data) {
      data.forEach(function(item) {
        App.PlaylistController.addPlaylist(item.playlist.name); 
      });
    });
  }
});

$(document).ready(function() {
  App.Track = Ember.Object.extend({});

  App.Playlist = Ember.Object.extend({});

  App.PlaylistController = Ember.ArrayController.create({
    content: [],

    addPlaylist: function(name) {
      this.pushObject(App.Playlist.create({name: name}));

      $.get("/playlists/add/" + name);
    },

    addEvent: function() {
      var name = $(".new-playlist").val();

      this.addPlaylist(name);

      return false;
    }
  });

  App.PlaylistView = Ember.View.extend({
    playlistsBinding: 'App.PlaylistController.content',
  });
});
