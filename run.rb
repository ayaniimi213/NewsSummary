#!/usr/bin/ruby
# -*- coding: cp932 -*-
# if you need to use proxy, modify $proxy in news.rb, NewsSummary.rb

class Command
	def Command.run(tag, topics_url)
		out = File.open(tag + "-" + topics_url + ".html", "w")
		open("| ruby NewsSummary.rb #{tag} #{topics_url}", "r"){|input|
			while line = input.gets
				out.puts line
			end
		}
		out.close
	end
end

if $0 == __FILE__
	#  <<TODO>> automatically extract topics from web portal site
	# 政治
	topics = %w(official_development_assistance yasukuni citizen_judge_system forced_labor_in_wwii the_constitution_of_japan social_insurance_agency_reform northern_territories economic_sanctions_on_north_korea regulation_reform japan_china_relations decrease_of_children)
	tag = "domestic"
#	topics.each{|topics_url|
#		puts "run #{topics_url}"
#		Command.run(tag, topics_url)
#	}
#	Command.run("world", "takeshima")

	# 教育
	topics = %w(scholastic_ability universities_reform educational_reform textbook shokuiku school_meal_costs bullying education high_school_entrance_examination general_education entrance_exam unified_middle_and_highschool_education school_refusal okinawa_mass_suicide_textbook_revision)
	tag = "domestic"
#	topics.each{|topics_url|
#		puts "run #{topics_url}"
#		Command.run(tag, topics_url)
#	}

#	puts "run aso_cabinet"
#	Command.run("domestic", "aso_cabinet")
#	Command.run("domestic", "scholastic_ability")
	puts "run androd"
	Command.run("computer", "android")

end
