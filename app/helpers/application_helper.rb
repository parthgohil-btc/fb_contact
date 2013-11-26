module ApplicationHelper
	def age(dob)
	  ((Date.today - dob).to_i / 365.25).ceil
  end
end
