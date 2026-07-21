class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Devise defaults every scope to root_path after sign in; send admins to
  # their own dashboard instead.
  def after_sign_in_path_for(resource)
    resource.is_a?(AdminUser) ? admin_root_path : super
  end
end
