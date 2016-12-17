class User < ApplicationRecord
  def finished?
    location && datetime && nights_count && budget_per_night
  end

  # parse wit context
  def wit_context
    if context_buffer
      return JSON.parse(context_buffer) 
    else
      self.context_buffer = {}.to_json
      self.save
      return {}
    end
  end

  def save_context_buffer(params)
    c = wit_context
    c.merge!(params)
    self.context_buffer = c.to_json
    self.save
  end

  def clean_context_buffer
    update_attribute(:context_buffer, nil)
  end
end
