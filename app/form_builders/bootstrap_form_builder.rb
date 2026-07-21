# Applies consistent Bootstrap styling to every form field by default, so
# individual views don't hand-repeat classes per field. Any `class:` passed
# at the call site is appended, not replaced. `select` gets Bootstrap's
# `form-select` (not `form-control`, which Bootstrap reserves for text-style
# inputs) — everything else in field_helpers gets `form-control`.
#
# Also applies Bootstrap's validation-error styling automatically: a field
# whose attribute has a validation error gets `is-invalid` plus an
# `invalid-feedback` div immediately after it (Bootstrap only shows that div
# when it directly follows an `.is-invalid` sibling), so views don't need to
# hand-check `object.errors` per field either.
class BootstrapFormBuilder < ActionView::Helpers::FormBuilder
  INPUT_CLASS = "form-control"
  SELECT_CLASS = "form-select"

  EXCLUDED = %i[label checkbox check_box radio_button fields_for fields hidden_field file_field].freeze

  (field_helpers - EXCLUDED).each do |selector|
    define_method(selector) do |method, options = {}|
      with_feedback(method) { super(method, styled(options, INPUT_CLASS, method)) }
    end
  end

  # field_helpers registers :textarea; Rails' own FormBuilder separately does
  # `alias_method :text_area, :textarea` at the PARENT class level. That
  # alias was captured before our override above existed, so without
  # re-aliasing here, `f.text_area` would silently keep calling the
  # original, unstyled implementation.
  alias_method :text_area, :textarea

  def select(method, choices = nil, options = {}, html_options = {}, &block)
    with_feedback(method) { super(method, choices, options, styled(html_options, SELECT_CLASS, method), &block) }
  end

  private

  def styled(options, base_class, method)
    classes = [ base_class, options[:class] ]
    classes << "is-invalid" if invalid_field?(method)
    options.merge(class: classes.compact.join(" "))
  end

  def invalid_field?(method)
    errors_for(method).present?
  end

  # `job_function_id` selects get their validation error on the association
  # name (`job_function`), not the foreign key; similarly a `_text` writer
  # accessor (e.g. `preferred_regions_text`) reports under the underlying
  # attribute (`preferred_regions`). Check both so the field still gets
  # `is-invalid` plus its message.
  def errors_for(method)
    return [] unless object.respond_to?(:errors)

    keys = [ method ]
    keys << method.to_s.sub(/_id\z/, "").to_sym if method.to_s.end_with?("_id")
    keys << method.to_s.sub(/_text\z/, "").to_sym if method.to_s.end_with?("_text")
    keys.flat_map { |key| object.errors[key] }
  end

  def with_feedback(method)
    html = yield
    errors = errors_for(method)
    return html if errors.empty?

    html + @template.content_tag(:div, errors.to_sentence.capitalize, class: "invalid-feedback")
  end
end
