function openShareUrl(url, initialWidth = 640, initialHeight = 480) {
  const width = Math.max(100, Math.min(screen.width, initialWidth));
  const height = Math.max(100, Math.min(screen.height, initialHeight));

  const left = (screen.width / 2) - (width / 2);
  const top = (screen.height * 0.3) - (height / 2);
  const opts = `width=${width},height=${height},left=${left},top=${top},menubar=no,status=no,location=no`;

  window.open(url, "popup", opts);
}

$(document).ready(function () {
  $(".ssb-icon").on("click", function (e) {
    e.preventDefault();
    const shareUrl = $(this).attr("href");
    if (shareUrl) {
      openShareUrl(shareUrl);
    }
  });
});

