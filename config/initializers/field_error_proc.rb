# Rails' default wraps any field with a validation error in a
# `<div class="field_with_errors">`. That div sits between the input and
# our BootstrapFormBuilder's `invalid-feedback` div, breaking the adjacent-
# sibling CSS (`.is-invalid ~ .invalid-feedback`) Bootstrap relies on to show
# it. BootstrapFormBuilder already marks invalid fields with `is-invalid`
# and renders the message itself, so disable Rails' own wrapping.
ActionView::Base.field_error_proc = proc { |html_tag, _instance| html_tag }
