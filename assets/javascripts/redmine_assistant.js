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

    var toggles = document.querySelectorAll('.redmine-assistant-toggle');
    for (var j = 0; j < toggles.length; j += 1) {
      toggles[j].addEventListener('click', function(event) {
        event.preventDefault();
        var target = document.getElementById(this.getAttribute('data-target'));
        if (!target) { return; }
        if (target.style.display === 'none' || target.style.display === '') {
          target.style.display = 'block';
          target.style.maxHeight = '0px';
          target.className += ' redmine-assistant-open';
          window.setTimeout(function() {
            target.style.maxHeight = target.scrollHeight + 'px';
          }, 1);
        } else {
          target.style.maxHeight = target.scrollHeight + 'px';
          window.setTimeout(function() {
            target.style.maxHeight = '0px';
          }, 1);
          window.setTimeout(function() {
            target.style.display = 'none';
          }, 220);
          target.className = target.className.replace(/\s?redmine-assistant-open/g, '');
        }
      });
    }
  });
})();
