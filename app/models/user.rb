class User < ApplicationRecord
  def finished?
    location && datetime && nights_count && budget_per_night
  end
end
