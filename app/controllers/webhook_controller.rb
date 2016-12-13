class WebhookController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index 
    @user = User.first
  end

  def bot
    #if params['hub.mode'] == 'subscribe' && params['hub.verify_token'] == 'hello_world'
    #  render plain: params['hub.challenge']
    #end
  end

  def send_message
    if params[:message].blank?
      redirect_to :back, notice: "Please send a message!"
    else
      @user = User.first
      wit = Wit.new(user: @user)
      context = {}
      %W(datetime location nights_count budget_per_night).each do |column|
        context[column.to_sym] = @user.send(column) unless @user.send(column).blank?
      end
      wit.send(params[:message], context)
      @responses = wit.context[:response].map{|x| x['text']}

      wit.context[:data].each do |data|
        data.each_pair do |key, value|
         @user.send("#{key}=", value) if @user.respond_to? key
        end
      end
      @user.save
    end

    render :index
  end

  def reset
    User.first.update_attributes(datetime:nil, location:nil, nights_count:nil, budget_per_night:nil)
    redirect_to "/webhook"
  end
end
