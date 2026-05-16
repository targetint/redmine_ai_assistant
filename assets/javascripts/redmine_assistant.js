(function() {
  function disableOnSubmit(form) {
    var button = form.querySelector('input[type="submit"], button[type="submit"]');
    if (!button) { return; }
    button.disabled = true;
    button.className += ' disabled';
  }

  document.addEventListener('DOMContentLoaded', function() {
    var forms = document.querySelectorAll('.redmine-assistant-sync-form, .redmine-assistant-summary-form');
    for (var i = 0; i < forms.length; i += 1) {
      forms[i].addEventListener('submit', function() {
        disableOnSubmit(this);
      });
    }
  });
})();
