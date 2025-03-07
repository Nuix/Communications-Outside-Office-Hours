script_directory = File.dirname(__FILE__)
require File.join(script_directory,"Nx.jar")
java_import "com.nuix.nx.NuixConnection"
java_import "com.nuix.nx.LookAndFeelHelper"
java_import "com.nuix.nx.dialogs.ChoiceDialog"
java_import "com.nuix.nx.dialogs.TabbedCustomDialog"
java_import "com.nuix.nx.dialogs.CommonDialogs"
java_import "com.nuix.nx.dialogs.ProgressDialog"
java_import "com.nuix.nx.dialogs.ProcessingStatusDialog"
java_import "com.nuix.nx.digest.DigestHelper"
java_import "com.nuix.nx.controls.models.Choice"

LookAndFeelHelper.setWindowsIfMetal
NuixConnection.setUtilities($utilities)
NuixConnection.setCurrentNuixVersion(NUIX_VERSION)

if $current_selected_items.nil? ||$current_selected_items.size < 1
	CommonDialogs.showWarning("Please select some items before running this script")
	exit 1
end

require File.join(script_directory,"CommunicationDateClassifier.rb")

office_day_choices = [
	"MONDAY",
	"TUESDAY",
	"WEDNESDAY",
	"THURSDAY",
	"FRIDAY",
	"SATURDAY",
	"SUNDAY",
]

default_office_days = [
	"MONDAY",
	"TUESDAY",
	"WEDNESDAY",
	"THURSDAY",
	"FRIDAY",
]

time_zone_id_choices = DateTimeZone.getAvailableIDs
default_time_zone_id = $current_case.getInvestigationTimeZone

dialog = TabbedCustomDialog.new("Communications Outside Office Hours")
dialog.enableStickySettings(File.join(script_directory,"Settings.json"))
dialog.setHelpUrl("https://github.com/Nuix/Communications-Outside-Office-Hours")

main_tab = dialog.addTab("maintab","Main")

main_tab.appendHeader("Office Hours/Days")
main_tab.appendComboBox("time_zone","Office Hours Time Zone",time_zone_id_choices)
main_tab.setText("time_zone",default_time_zone_id)
main_tab.appendTextField("office_hours_start","Office Hours Start (24 hour HH:MM)","09:00")
main_tab.appendTextField("office_hours_end","Office Hours End (24 hour HH:MM)","17:00")
main_tab.appendMultipleChoiceComboBox("office_days","Office Days",office_day_choices,default_office_days)

main_tab.appendHeader("Tags")
main_tab.appendTextField("parent_tag","Parent Tag (can be blank)","Office Hours")
main_tab.appendTextField("before_tag","Before Hours Tag","Before Office Hours")
main_tab.appendTextField("after_tag","After Hours Tag","After Office Hours")
main_tab.appendTextField("during_tag","During Hours Tag","During Office Hours")
main_tab.appendTextField("weekend_tag","Weekend Tag","Weekend")
main_tab.appendCheckBox("record_day_of_week","Record Day of Week",false)

dialog.validateBeforeClosing do |values|
	start_hour = 0
	start_minutes = 0
	end_hour = 23
	end_minutes = 59

	# Validate start time
	if values["office_hours_start"].strip.empty?
		CommonDialogs.showWarning("Please provide a value for 'Office Hours Start'")
		next false
	else
		begin
			start_hour,start_minutes = CommunicationDateClassifier.parse_hour_minutes_string(values["office_hours_start"])
		rescue Exception => exc
			CommonDialogs.showWarning("Invalid 'Office Hours Start': #{exc.message}")
			next false	
		end
	end

	# Validate end time
	if values["office_hours_end"].strip.empty?
		CommonDialogs.showWarning("Please provide a value for 'Office Hours End'")
		next false
	else
		begin
			end_hour,end_minutes = CommunicationDateClassifier.parse_hour_minutes_string(values["office_hours_end"])
		rescue Exception => exc
			CommonDialogs.showWarning("Invalid 'Office Hours End': #{exc.message}")
			next false	
		end
	end

	# Verify start time is before end time
	if start_hour > end_hour || (start_hour == end_hour && start_minutes > end_minutes)
		CommonDialogs.showWarning("'Office Hours Start' cannot be before 'Office Hours End'")
		next false
	elsif start_hour == end_hour && start_minutes == end_minutes
		CommonDialogs.showWarning("'Office Hours Start' cannot be the same as 'Office Hours End'")
		next false
	end

	# ===============================================
	# Verify that all sub-tags have a non-empty value
	# ===============================================

	if values["before_tag"].strip.empty?
		CommonDialogs.showWarning("'Before Hours Tag' cannot be empty")
		next false
	end

	if values["during_tag"].strip.empty?
		CommonDialogs.showWarning("'During Hours Tag' cannot be empty")
		next false
	end

	if values["after_tag"].strip.empty?
		CommonDialogs.showWarning("'After Hours Tag' cannot be empty")
		next false
	end

	if values["weekend_tag"].strip.empty?
		CommonDialogs.showWarning("'Weekend Tag' cannot be empty")
		next false
	end

	# Verify that user selected at least one office day
	if values["office_days"].size < 1
		CommonDialogs.showWarning("Please select at least 1 'Office Days' value")
		next false
	end

	next true
end

# Show the settings dialog
dialog.display

# User clicked okay and all validations passed
if dialog.getDialogResult == true
	values = dialog.toMap

	time_zone = values["time_zone"]
	office_hours_start = values["office_hours_start"]
	office_hours_end = values["office_hours_end"]
	office_days = values["office_days"]
	# Make office days array into Hash
	office_days = office_days.map{|d| [d,true] }.to_h
	parent_tag = values["parent_tag"]
	before_tag = values["before_tag"]
	during_tag = values["during_tag"]
	after_tag = values["after_tag"]
	weekend_tag = values["weekend_tag"]
	record_day_of_week = values["record_day_of_week"]

	# Show progress dialog while we do the main work
	ProgressDialog.forBlock do |pd|
		pd.setAbortButtonVisible(false)
		pd.setTitle("Communications Outside Office Hours")
		pd.onMessageLogged{|message| puts message}
		
		# Create comms classifier and configure tags based
		# on settings provided by user
		classifier = CommunicationDateClassifier.new(time_zone,office_hours_start,office_hours_end)
		classifier.parent_tag = parent_tag
		classifier.before_tag = before_tag
		classifier.during_tag = during_tag
		classifier.after_tag = after_tag
		classifier.weekend_tag = weekend_tag
		office_day_choices.each do |day_of_week|
			classifier.office_days[day_of_week] = (office_days[day_of_week] == true)
		end
		classifier.record_week_day = record_day_of_week
		
		# Hookup progress to progress dialog
		classifier.on_message_logged{|message| pd.logMessage(message)}
		classifier.on_progress do |current,total|
			pd.setMainProgress(current,total)
			if current % 1000 == 0
				pd.setMainStatus("#{current}/#{total}")
			end
		end

		# Log the settings we will be using
		pd.logMessage(classifier.to_s)
		
		# Perform classification
		classifier.classify_items($current_selected_items)
		
		# Set dialog to completed
		pd.setCompleted
	end
end