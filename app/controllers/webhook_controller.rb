class WebhookController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index 
    @user = User.first
  end

  def bot
    messenger_bot_id = '631366967034247'

    # for webhook verification
    #if params['hub.mode'] == 'subscribe' && params['hub.verify_token'] == 'hello_world'
    #  render plain: params['hub.challenge']
    #end

    ############################################
    # 1. receive message from Messenger Webhook
    # 2. authenticate current_user
    #    1) if user does not exist, create a new user
    #    2) if user exists, set it as current_user
    # 3. send message to Wit
    # 4. get feedback from Wit
    #    1) save the info into database
    #    2) send info back to Messenger
    ############################################

    # send msg to Wit
    wit = Wit.new(user: current_user)
    # context = {}

    #%W(datetime location nights_count budget_per_night amenities).each do |column|
    #  context[column.to_sym] = current_user.send(column) unless current_user.send(column).blank?
    #end

    message_folder = params['entry'][0]['messaging'][0]['message']
    recipient_id = params['entry'][0]['messaging'][0]['recipient']['id']

    if message_folder && recipient_id == messenger_bot_id
      message = message_folder['text']
      logger.info "=== send MSG to Wit...: #{message}"
      logger.info "--- context buffer: #{current_user.wit_context}"
      wit.send(message)

      # get feedback from Wit
      logger.info "=== response from Wit..."
      responses = wit.context[:response].map{|x| x['text']}

      # save the info into database
      wit.context[:data].each do |data|
        data.each_pair do |key, value|
          current_user.send("#{key}=", value) if current_user.respond_to? key
        end
      end
      logger.info "=== save user..."
      current_user.save
	    
      # send info back to Messenger
      logger.info "=== send to FB..."
      send_message_to_user(responses)
    end

    render plain: 'OK', status: 200
  end

  def send_message
    if params[:message].blank?
      redirect_to :back, notice: "Please send a message!"
    else
      @user = User.first
      # wit = Wit.new(user: @user, logger: logger)
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

  def send_message_to_user(responses)
    recipient_id = current_user.fb_id
    sender_id = params['entry'][0]['messaging'][0]['recipient']['id']

    responses.each do |res|
      msg = {
        recipient: {
          id: recipient_id
        }, 
        message: {
          text: res
        }, 
        access_token: 'EAAO9pZAHgYicBAFkiBnStOEPDOBmKuZC5ZC5EqmQCKsjgLraDZAEVNu5dTOwyO4SCKBhc1XArINEmgVNZCHTwqCEusE8FOwelg110ZBIZBoTxv60ucZBSM3CuitW5dHsv3zAcqCug9ZBL1Hx9W68sybd5y6BSkBpQJV0Ku5pVqJHUPQZDZD'
      }

      call_send_api(msg)
    end
  end

  # send message to Facebook Messenger
  def call_send_api(msg)
    ret = Faraday.post("https://graph.facebook.com/v2.6/me/messages", msg)
  end
end
