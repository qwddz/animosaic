// Show the section in the visitor's language first (uk, ru, else en),
// unless the link already points at a section.
(function () {
  if (location.hash) return;
  var lang = (navigator.language || 'en').slice(0, 2);
  var section = document.getElementById(lang === 'uk' || lang === 'ru' ? lang : 'en');
  if (section && lang !== 'en') section.scrollIntoView();
})();
