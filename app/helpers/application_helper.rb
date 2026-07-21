module ApplicationHelper
  # For checkbox-group fields (languages, employment types, working days)
  # built with raw check_box_tag rather than the form builder — they have
  # no single input to red-border, so give the group container a red
  # border and render the message manually. `d-block` is required because
  # this isn't an adjacent sibling of an `.is-invalid` input, so Bootstrap's
  # `.is-invalid ~ .invalid-feedback` selector wouldn't otherwise show it.
  def group_validation_class(object, attribute)
    "border border-danger rounded-2 p-2" if object.errors[attribute].present?
  end

  def group_validation_feedback(object, attribute)
    return unless object.errors[attribute].present?

    content_tag(:div, object.errors[attribute].to_sentence.capitalize, class: "invalid-feedback d-block mt-1")
  end
end
