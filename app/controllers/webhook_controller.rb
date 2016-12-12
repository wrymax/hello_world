class WebhookController < ApplicationController
  def index 
  end

  def send
    if params[:message].blank?
      redirect_to :back, notice: "Please send a message!"
    else
      wit = Wit.new(user: User.first)
      ret = wit.send(params[:message])
    end
  end
end
