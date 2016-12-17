class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  helper_method :current_user#, :wit

  def current_user
    return @current_user if @current_user

    if params['entry']
      fb_id = params['entry'][0]['messaging'][0]['sender']['id']
      if user = User.find_by_fb_id(fb_id)
        @current_user = user
      else
        @current_user = User.create(fb_id: fb_id)
      end
    end

    return @current_user
  end

=begin
  # a shared wit instance for a session
  def wit
    @wit = session[:wit] 
    unless @wit
      @wit = Wit.new(user: current_user)
      session[:wit] = @wit
    end
    return @wit
  end
=end

end
