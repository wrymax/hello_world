require 'json'
require 'logger'
require 'net/http'
require 'securerandom'

class Wit
  class Error < StandardError; end
  attr_accessor :context, :user, :logger

  WIT_API_HOST = ENV['WIT_URL'] || 'https://api.wit.ai'
  WIT_API_VERSION = ENV['WIT_API_VERSION']  || '20160516'
  DEFAULT_MAX_STEPS = 5
  LEARN_MORE = 'Learn more at https://wit.ai/docs/quickstart'

  # default app access_token
  ACCESS_TOKEN = 'JXVYOWKYSALWMULHVNLRUTZ4XU6HGYPV'

  def initialize(opts = {})
    @access_token = opts[:access_token] || ACCESS_TOKEN

    if opts[:logger]
      @logger = opts[:logger]
    end

    # if opts[:actions]
    #   @actions = validate_actions(logger, opts[:actions])
    # end

    # pre-define the actions
    @actions = __actions

    # own an user
    @user = opts[:user]

    # context buffer to save return message
    @context = {response: [], data: []}
    @_sessions = {}
  end

  def logger
    @logger ||= begin
      x = Logger.new(STDOUT)
      x.level = Logger::INFO
      x
    end
  end

  def message(msg)
    params = {}
    params[:q] = msg unless msg.nil?
    res = req(logger, @access_token, Net::HTTP::Get, '/message', params)
    return res
  end

  def converse(session_id, msg, context={}, reset=nil)
    if !context.is_a?(Hash)
      raise Error.new('context should be a Hash')
    end
    params = {}
    params[:q] = msg unless msg.nil?
    params[:session_id] = session_id
    params[:reset] = true if reset
    res = req(logger, @access_token, Net::HTTP::Post, '/converse', params, context)
    return res
  end

  def run_actions(session_id, message, context={}, max_steps=DEFAULT_MAX_STEPS)
    if !@actions
      throw_must_have_actions
    end
    if !context.is_a?(Hash)
      raise Error.new('context should be a Hash')
    end

    # Figuring out whether we need to reset the last turn.
    # Each new call increments an index for the session.
    # We only care about the last call to run_actions.
    # All the previous ones are discarded (preemptive exit).
    current_request = 1
    if @_sessions.has_key?(session_id)
      current_request = @_sessions[session_id] + 1
    end
    @_sessions[session_id] = current_request

    context = __run_actions(session_id, current_request, message, context, max_steps)

    # Cleaning up once the last call to run_actions finishes.
    if current_request == @_sessions[session_id]
      @_sessions.delete(session_id)
    end

    return context
  end

  # for controller to interact with Wit
  def send(msg, context={}, max_steps=DEFAULT_MAX_STEPS)
    if !@actions
      throw_must_have_actions
    end

    if @user.session_id
      session_id = @user.session_id
    else
      session_id = SecureRandom.uuid
      @user.update_attribute(:session_id, session_id)
    end

    begin
      # run_actions
      # context = run_actions(session_id, msg, context, max_steps)
    
      # use @context_buffer instead
      context = run_actions(session_id, msg, @user.wit_context, max_steps)
    rescue Error => exp
      logger.error("error: #{exp.message}")
    end
  end

=begin
  def interactive(context={}, max_steps=DEFAULT_MAX_STEPS)
    if !@actions
      throw_must_have_actions
    end

    session_id = SecureRandom.uuid
    # 开启一个死循环，模拟一个交互session
    while true
      print '> '
      msg = STDIN.gets.strip
      if msg == ''
        next
      end

      begin
        # run_actions
        context = run_actions(session_id, msg, context, max_steps)
      rescue Error => exp
        logger.error("error: #{exp.message}")
      end
    end
  rescue Interrupt => _exp
    puts
  end
=end

  def throw_if_action_missing(action_name)
    if !@actions.has_key?(action_name)
      raise Error.new("unknown action: #{action_name}")
    end
  end

  def throw_must_have_actions()
    raise Error.new('You must provide the `actions` parameter to be able to use runActions. ' + LEARN_MORE)
  end

  def get_entities
    req(logger, @access_token, Net::HTTP::Get, "/entities")
  end

  def post_entities(payload)
    payload = payload.map {|k, v| [(k.to_sym rescue k), v]}.to_h.reject{ |k| ![:id, :doc, :values, :lookups].include?(k) }
    validate_payload payload
    req(logger, @access_token, Net::HTTP::Post, "/entities", {}, payload)
  end

  def get_entity(entity_id)
    req(logger, @access_token, Net::HTTP::Get, "/entities/#{URI.encode(entity_id)}")
  end

  def put_entities(entity_id, payload)
    payload = payload.map {|k, v| [(k.to_sym rescue k), v]}.to_h.reject{ |k| ![:id, :doc, :values].include?(k) }
    validate_payload payload
    req(logger, @access_token, Net::HTTP::Put, "/entities/#{URI.encode(entity_id)}", {}, payload)
  end

  def delete_entities(entity_id)
    req(logger, @access_token, Net::HTTP::Delete, "/entities/#{URI.encode(entity_id)}")
  end

  def post_values(entity_id, payload)
    payload = payload.map {|k, v| [(k.to_sym rescue k), v]}.to_h.reject{ |k| ![:value, :expressions, :metadata].include?(k) }
    validate_payload payload
    req(logger, @access_token, Net::HTTP::Post, "/entities/#{URI.encode(entity_id)}/values", {}, payload)
  end

  def delete_values(entity_id, value)
    req(logger, @access_token, Net::HTTP::Delete, "/entities/#{URI.encode(entity_id)}/values/#{URI.encode(value)}")
  end

  def post_expressions(entity_id, value, payload)
    payload = payload.map {|k, v| [(k.to_sym rescue k), v]}.to_h.reject{ |k| ![:expression].include?(k) }
    validate_payload payload
    req(logger,@access_token, Net::HTTP::Post, "/entities/#{URI.encode(entity_id)}/values/#{URI.encode(value)}/expressions", {}, payload)
  end

  def delete_expressions(entity_id, value, expression)
    req(logger,@access_token, Net::HTTP::Delete, "/entities/#{URI.encode(entity_id)}/values/#{URI.encode(value)}/expressions/#{URI.encode(expression)}")
  end

  private

  def validate_payload(payload)
    key_types = {
      id: String,
      doc: String,
      value: String,
      values: Array,
      lookups: Array,
      expression: String,
      expressions: Array,
      metadata: String,
    }
    payload.each do |k, v|
      raise Error.new("#{k.to_s} in request body must be #{key_types[k].to_s} type") unless key_types[k] == v.class
    end
  end

  def __run_actions(session_id, current_request, message, context, i)
    if i <= 0
      raise Error.new('Max steps reached, stopping.')
    end
    json = converse(session_id, message, context)
    if json['type'].nil?
      raise Error.new('Couldn\'t find type in Wit response')
    end
    if current_request != @_sessions[session_id]
      return context
    end

    logger.debug("Context: #{context}")
    logger.debug("Response type: #{json['type']}")

    # backwards-compatibility with API version 20160516
    if json['type'] == 'merge'
      json['type'] = 'action'
      json['action'] = 'merge'
    end

    if json['type'] == 'error'
      raise Error.new('Oops, I don\'t know what to do.')
    end

    if json['type'] == 'stop'
      return context
    end

    request = {
      'session_id' => session_id,
      'context' => context.clone,
      'text' => message,
      'entities' => json['entities']
    }
    # 向Wit发消息
    if json['type'] == 'msg'
      throw_if_action_missing(:send)
      response = {
        'text' => json['msg'],
        'quickreplies' => json['quickreplies'],
      }
      context = @actions[:send].call(request, response)
      @context[:response].push(context)
    # 获取Wit的回调action，执行这个@actions[action]
    elsif json['type'] == 'action'
      action = json['action'].to_sym
      throw_if_action_missing(action)
      context = @actions[action].call(request)
      if context.nil?
        logger.warn('missing context - did you forget to return it?')
        context = {}
      else
        @context[:data].push(context)
      end
    else
      raise Error.new("unknown type: #{json['type']}")
    end

    # insert a new context in the buffer

    if current_request != @_sessions[session_id]
      return context
    end

    # 递归处理
    return __run_actions(session_id, current_request, nil, context, i - 1)
  end

  def req(logger, access_token, meth_class, path, params={}, payload={})
    uri = URI(WIT_API_HOST + path)
    uri.query = URI.encode_www_form(params)

    logger.debug("#{meth_class} #{uri}")

    request = meth_class.new(uri)
    request['authorization'] = 'Bearer ' + access_token
    request['accept'] = 'application/vnd.wit.' + WIT_API_VERSION + '+json'
    request.add_field 'Content-Type', 'application/json'
    request.body = payload.to_json

    Net::HTTP.start(uri.host, uri.port, {:use_ssl => uri.scheme == 'https'}) do |http|
      rsp = http.request(request)
      if rsp.code.to_i != 200
        raise Error.new("HTTP error code=#{rsp.code}")
      end
      json = JSON.parse(rsp.body)
      if json.is_a?(Hash) and json.has_key?('error')
        raise Error.new("Wit responded with an error: #{json['error']}")
      end
      logger.debug("#{meth_class} #{uri} #{json}")
      json
    end
  end

  def validate_actions(logger, actions)
    [:send].each do |action|
      if !actions.has_key?(action)
        logger.warn "The #{action} action is missing. #{LEARN_MORE}"
      end
    end
    actions.each_pair do |k, v|
      if !k.is_a?(Symbol)
        logger.warn "The '#{k}' action name should be a symbol"
      end
      if !(v.respond_to?(:call) && v.lambda?)
        logger.warn "The '#{k}' action should be a lambda function"
      end
      if k == :send && v.arity != 2
        logger.warn "The \'send\' action should take 2 arguments: request and response. #{LEARN_MORE}"
      end
      if k != :send && v.arity != 1
        logger.warn "The '#{k}' action should take 1 argument: request. #{LEARN_MORE}"
      end
    end
    return actions
  end

  def first_entity_value(entities, entity)
    return nil unless entities.has_key? entity
    val = entities[entity][0]['value']
    return nil if val.nil?
    return val.is_a?(Hash) ? val['value'] : val
  end

  def __actions
    return {
      send: -> (request, response) {
        puts("sending... #{response['text']}")
        return response
      },
      getLocation: -> (request) {
        logger.info "\n *** Calling getLocation ***"
        context = request['context']
        entities = request['entities']

        loc = first_entity_value(entities, 'location')
        if loc
            context.delete('missingLocation')
            @user.update_attributes(:location => loc)
            @user.save_context_buffer(location: loc)
            context['location'] = loc
        else
            context['missingLocation'] = true
        end

        return context
      },
      getArriveDate: -> (request) {
        logger.info "\n *** Calling getArriveDate ***"
        context = request['context']
        entities = request['entities']

        datetime = first_entity_value(entities, 'datetime')
        if datetime
            context.delete('missingDatetime')
            datetime = datetime.match(/\d+-\d+-\d+/).to_s
            @user.update_attribute(:datetime, datetime)
            context['datetime'] = datetime
            @user.save_context_buffer(datetime: datetime)
        else
            context['missingDatetime'] = true
        end


        return context
      },
      getNights: -> (request) {
        logger.info "\n *** Calling getNights ***"
        context = request['context']
        entities = request['entities']

        nights_count = first_entity_value(entities, 'nights_count') || first_entity_value(entities, 'number')
        nights_count = nights_count.to_i.to_s

        if nights_count
            context.delete('missingNightsCount')
            @user.update_attribute(:nights_count, nights_count)
            context['nights_count'] = nights_count
            @user.save_context_buffer(nights_count: nights_count)
        else
            context['missingNightsCount'] = true
        end

        return context
      },

      getBudgetPerNight: -> (request) {
        logger.info "\n *** Calling getNights ***"
        context = request['context']
        entities = request['entities']

        budget_per_night = first_entity_value(entities, 'budget_per_night') || first_entity_value(entities, 'number')
        if budget_per_night
            context.delete('missingBudgetPerNight')
            context['budget_per_night'] = budget_per_night
            # here is something wrong with the Wit config about "3 nights"...
            context['nights_count'] = "#{@user.nights_count} nights"
            @user.update_attribute(:budget_per_night, budget_per_night)
            @user.save_context_buffer(budget_per_night: budget_per_night)
        else
            context['missingBudgetPerNight'] = true
        end

        return context
      },

      getAmenities: -> (request) {
        logger.info "\n *** Calling getAmenities ***"
        ap "\n *** Calling getAmenities ***"
        context = request['context']
        entities = request['entities']
        amenities = entities['amenities'].map{|e| e['value']}.join(', ')

        if amenities 
            context.delete('missingAmenities')
            @user.update_attribute(:amenities, amenities)
            context['amenities'] = amenities
            # clean session
            @user.session_id = nil
            @user.save
            # @user.save_context_buffer(amenities: amenities)
            @user.clean_context_buffer # clean context buffer when the last action is finished
        else
            context['missingAmenities'] = true
        end

        return context
      }
    }
  end
end
