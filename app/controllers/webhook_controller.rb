class WebhookController < ApplicationController
  def index 
    logger.info "------------------"
    ap params
    logger.info "------------------"
    render plain: params.inspect
  end
end
