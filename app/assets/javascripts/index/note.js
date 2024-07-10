OSM.Note = function (map) {
  var content = $("#sidebar_content"),
      page = {};

  var noteIcons = {
    "new": L.icon({
      iconUrl: OSM.NEW_NOTE_MARKER,
      iconSize: [25, 40],
      iconAnchor: [12, 40]
    }),
    "open": L.icon({
      iconUrl: OSM.OPEN_NOTE_MARKER,
      iconSize: [25, 40],
      iconAnchor: [12, 40]
    }),
    "closed": L.icon({
      iconUrl: OSM.CLOSED_NOTE_MARKER,
      iconSize: [25, 40],
      iconAnchor: [12, 40]
    })
  };

  page.pushstate = page.popstate = function (path, id) {
    OSM.loadSidebarContent(path, function () {
      initialize(path, id, function () {
        var data = $(".details").data();
        if (!data) return;
        var latLng = L.latLng(data.coordinates.split(","));
        if (!map.getBounds().contains(latLng)) moveToNote();
      });
    });
  };

  page.load = function (path, id) {
    initialize(path, id, moveToNote);
  };

  function initialize(path, id, callback) {
    content.find("button[type=submit]").on("click", function (e) {
      e.preventDefault();
      var data = $(e.target).data();
      var form = e.target.form;

      $(form).find("button[type=submit]").prop("disabled", true);

      $.ajax({
        url: data.url,
        type: data.method,
        oauth: true,
        data: { text: $(form.text).val() },
        success: function () {
          OSM.loadSidebarContent(path, function () {
            initialize(path, id, moveToNote);
          });
        },
        error: function (xhr) {
          $(form).find("#comment-error")
            .text(xhr.responseText)
            .prop("hidden", false);
          updateButtons(form);
        }
      });
    });

    content.find("textarea").on("input", function (e) {
      updateButtons(e.target.form);
    });

    content.find("textarea").val("").trigger("input");

    var data = $(".details").data();

    if (data) {
      map.addObject({
        type: "note",
        id: parseInt(id, 10),
        latLng: L.latLng(data.coordinates.split(",")),
        icon: noteIcons[data.status]
      });
    }

    if (callback) callback();
  }

  function updateButtons(form) {
    $(form).find("button[type=submit]").prop("disabled", false);
    if ($(form.text).val() === "") {
      $(form.close).text($(form.close).data("defaultActionText"));
      $(form.comment).prop("disabled", true);
    } else {
      $(form.close).text($(form.close).data("commentActionText"));
      $(form.comment).prop("disabled", false);
    }
  }

  function moveToNote() {
    var data = $(".details").data();
    if (!data) return;
    var latLng = L.latLng(data.coordinates.split(","));

    if (!window.location.hash || window.location.hash.match(/^#?c[0-9]+$/)) {
      OSM.router.withoutMoveListener(function () {
        map.setView(latLng, 15, { reset: true });
      });
    }
  }

  page.unload = function () {
    map.removeObject();
  };

  return page;
};
