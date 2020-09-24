java_import org.joda.time.DateTimeZone

class CommunicationDateClassifier
	attr_accessor :start_hour
	attr_accessor :start_minutes
	attr_accessor :end_hour
	attr_accessor :end_minutes

	attr_accessor :office_days

	attr_accessor :parent_tag
	attr_accessor :before_tag
	attr_accessor :during_tag
	attr_accessor :after_tag
	attr_accessor :weekend_tag

	attr_accessor :message_logged_callback
	attr_accessor :progress_callback

	# Parses input time string such as "09:00" into an hours part (9) and
	# a minutes part (0).  Expects hours to be specified in 24 hour time
	# format (0 -23)
	def self.parse_hour_minutes_string(input)
		if input !~ /[0-9]{2}:[0-9]{2}/
			raise "Time must be specified 'HH:MM' (24 hour), provided: #{input}"
		end

		pieces = input.strip.split(":")

		hour = pieces[0].to_i
		minutes = pieces[1].to_i

		if hour < 0 || hour > 23
			raise "Hour must be between 0 and 23, provided: #{hour}"
		end

		if minutes < 0 || minutes > 59
			raise "Minutes must be between 0 and 59, provided: #{minutes}"
		end

		return hour,minutes
	end

	# Create a new instance
	# time_zone_id = Time zone communication datetimes will be coerced to before comparison
	# from = Time that office hours starts, expects 24 hour time string like "09:00"
	# to = Time that office hours end, expects 24 hour time string like "17:00"
	def initialize(time_zone_id=nil,from="09:00",to="17:00")
		if @time_zone_id.nil? || @time_zone_id.strip.empty?
			@time_zone = DateTimeZone.getDefault
		else
			@time_zone = DateTimeZone.forID(time_zone_id)
		end
		@start_hour,@start_minutes = CommunicationDateClassifier.parse_hour_minutes_string(from)
		@end_hour,@end_minutes = CommunicationDateClassifier.parse_hour_minutes_string(to)

		@parent_tag = "Office Hours"
		@before_tag = "Before Office Hours"
		@during_tag = "During Office Hours"
		@after_tag = "After Office Hours"
		@weekend_tag = "Weekend"

		@office_days = {
			"MONDAY" => true,
			"TUESDAY" => true,
			"WEDNESDAY" => true,
			"THURSDAY" => true,
			"FRIDAY" => true,
			"SATURDAY" => false,
			"SUNDAY" => false,
		}

		@week_day_names = {
			1 => "MONDAY",
			2 => "TUESDAY",
			3 => "WEDNESDAY",
			4 => "THURSDAY",
			5 => "FRIDAY",
			6 => "SATURDAY",
			7 => "SUNDAY",
		}
	end

	def on_message_logged(&block)
		@message_logged_callback = block
	end

	def on_progress(&block)
		@progress_callback = block
	end

	def log(message)
		if !@message_logged_callback.nil?
			@message_logged_callback.call(message)
		else
			puts message
		end
	end

	def fire_progress(current,total)
		if !@progress_callback.nil?
			@progress_callback.call(current,total)
		end
	end

	def to_s
		result =[]
		result << "Time Zone: #{@time_zone}"
		start_time_string = "#{@start_hour.to_s.rjust(2,"0")}:#{@start_minutes.to_s.rjust(2,"0")}"
		end_time_string  = "#{@end_hour.to_s.rjust(2,"0")}:#{@end_minutes.to_s.rjust(2,"0")}"
		result << "Office Hours: #{start_time_string} - #{end_time_string}"
		result << "Office Days:"
		@office_days.each{|k,v| result << "#{k} => #{v}"}
		return result.join("\n")
	end

	# Classifies provided items using office hours and office days of the week into
	# having a communication time that is:
	# - Before office hours
	# - During office hours
	# - After office hours
	# - During Weekend
	def classify_items(items)
		tag_batches = Hash.new{|h,k| h[k] = []}
		annotater = $utilities.getBulkAnnotater

		# Build final tags up front (parent|child), logic is so that parent tag can be blank/nil
		# and we still build a usable tag
		before_tag_final = [@parent_tag,@before_tag].reject{|t|t.nil? || t.strip.empty?}.join("|")
		after_tag_final = [@parent_tag,@after_tag].reject{|t|t.nil? || t.strip.empty?}.join("|")
		during_tag_final = [@parent_tag,@during_tag].reject{|t|t.nil? || t.strip.empty?}.join("|")
		weekend_tag_final = [@parent_tag,@weekend_tag].reject{|t|t.nil? || t.strip.empty?}.join("|")

		# We will track how many of each tag we applied so we can report
		# this to user at the end of the process
		classification_counts = Hash.new{|h,k| h[k] = 0}

		items.each_with_index do |item,item_index|
			fire_progress(item_index+1,items.size)
			communication = item.getCommunication
			if communication.nil?
				# Record this item had no communication
				classification_counts["Not Communication"] += 1
			else
				communication_date = communication.getDateTime
				if communication_date.nil?
					# Record this item had no comm date
					classification_counts["No Communication Date"] += 1
				else
					zoned_communication_date = communication_date.withZone(@time_zone)
					week_day_name = @week_day_names[zoned_communication_date.getDayOfWeek]

					# Should we apply a weekend tag?
					if @office_days[week_day_name] != true
						tag = weekend_tag_final
					else
						# Does appear to be on a weekend so we test whether
						# time is before, during or after normal office hours
						hour_of_day = zoned_communication_date.getHourOfDay
						minute_of_hour = zoned_communication_date.getMinuteOfHour

						# We check first if is before office hours, then we check if after office hours, finally
						# if not before or after then should be during
						if hour_of_day < @start_hour || (hour_of_day == @start_hour && minute_of_hour < @start_minutes)
							tag = before_tag_final
						elsif hour_of_day > @end_hour || (hour_of_day == @end_hour && minute_of_hour > @end_minutes)
							tag = after_tag_final
						else
							tag = during_tag_final
						end
					end

					# Try to batch add tags a little bit so we get better performance
					tag_batches[tag] << item
					if tag_batches[tag].size >= 500
						annotater.addTag(tag,tag_batches[tag])
						log("Applied tag '#{tag}' to #{tag_batches[tag].size} items")
						classification_counts[tag] += tag_batches[tag].size
						tag_batches.delete(tag)
					end
				end
			end
		end

		# Make sure to tag anything left in tag_batches
		tag_batches.each do |tag,items|
			annotater.addTag(tag,items)
			log("Applied tag '#{tag}' to #{items.size} items")
			classification_counts[tag] += items.size
			tag_batches.delete(tag)
		end

		# Report final counts
		log("Items Processed: #{items.size}")
		classification_counts.each do |classification,count|
			log("#{classification}: #{count}")
		end
	end
end

=begin

# =============
# Example Usage
# =============

# Create instance with customized office hours and time zone
comm_time_classifier = CommunicationDateClassifier.new("America/Los_Angeles","07:45","17:45")

# This office is lucky and Monday is considered part of the weekend (in addition to Saturday and Sunday)
comm_time_classifier.office_days["MONDAY"] = false

# Customize the root tag
comm_time_classifier.parent_tag = "Custom Office Hours"

# Define sub-tags
comm_time_classifier.before_tag = "Suspiciously Early"
comm_time_classifier.after_tag = "Suspiciously Late"
comm_time_classifier.during_tag = "Hard Worker"
comm_time_classifier.weekend_tag = "Really Hard Worker"

# Get some items
items = $current_case.search("kind:email",{"limit"=>1000})

# Classify (tag) them
comm_time_classifier.classify_items(items)

=end