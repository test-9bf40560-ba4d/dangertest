OSM.Home = function (map) {
  var marker;

  function clearMarker() {
    if (marker) map.removeLayer(marker);
    marker = null;
  }

  var page = {};

  page.pushstate = page.popstate = page.load = function () {
    map.setSidebarOverlaid(true);
    clearMarker();

    if (OSM.home) {
      OSM.router.withoutMoveListener(function () {
        map.setView(OSM.home, 15, { reset: true });
      });
      marker = L.marker(OSM.home, {
        icon: OSM.getUserIcon(),
        title: I18n.t("javascripts.home.marker_title")
      }).addTo(map);
    } else {
      $("#browse_status").html(
        $("<div class='m-2 alert alert-warning'>").text(
          I18n.t("javascripts.home.not_set")
        )
      );
    }
  };

  page.unload = function () {
    clearMarker();
    $("#browse_status").empty();
  };

  return page;
};
