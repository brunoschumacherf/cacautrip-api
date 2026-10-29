class Conversation < ApplicationRecord
  belongs_to :tourist
  belongs_to :guide
  belongs_to :driver
end
