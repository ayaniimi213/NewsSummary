#!/usr/bin/ruby
# -*- coding: utf-8 -*-
require 'open-uri'
$KCODE = "u"
require 'kconv'
#require 'MeCab' # need install MeCab and see mecab document
require 'easymecab'
require 'News'
$proxy = 'http://localhost:8080/' # or nil
$debug = false # true or false

$max_pages = 1
$time_frame = (60 * 60 * 24)
$score_threshold = 15

class NewsSummary

	# SETTINGS
	def initialize
		@topics = ""
	end

	def process(args, default_io)
		tag = args[0]
		topics_url = args[1]
		tag = "domestic" if args[0] == ""
		topics_url = "scholastic_ability" if args[1] == ""
		base_url = "http://dailynews.yahoo.co.jp/fc/"
		p tag if $debug
		p topics_url if $debug

		@contents = Hash.new() # hash key is url
		@keywords = Hash.new() # hash key is url
		@titles = Hash.new() # hash key is url
		@sources = Hash.new() # hash key is url
		@times = Hash.new() # hash key is url
		@wordcount = Hash.new(0) # hash key is word

		# get topics
#		@topics = get_topics(base_url + tag + "/" + topics_url + "/index.html")
#		p base_url + tag + "/" + topics_url + "/index.html"
		@topics = get_topics(base_url + tag + "/" + topics_url + "/news_list/")
		p base_url + tag + "/" + topics_url + "/news_list/" if $debug
		output_header(@topics, base_url + tag + "/" + topics_url + "/news_list/")

		# multi page handling
		STDERR << "get news\n"
		(1..$max_pages).each{|i|
#			extract_links(base_url + tag + "/" + topics_url + "/news_stories_" + i.to_s + ".html").each{|url|
			extract_links(base_url + tag + "/" + topics_url + "/news_list/?pn=" + i.to_s).each{|url|
				news = News.new
				begin
					news.store(url)
				rescue
					p $!
					next
				end
				STDERR << "."
				
				# store each contents
				content = news.get_content()
				next if content.nil?
				title = news.get_title()
				@titles[url] = title
				p title if $debug
				source = news.get_source()
				@sources[url] = source
				p source if $debug
				time = news.get_time()
				@times[url] = time
				p time.to_s if $debug

				@contents[url] = content
				p @contents[url] if $debug
				# parse words by MeCab
				m = MeCab.new("")
				n = m.parse(title + "\n" + content)
				@keywords[url] = strip_by_wordclass(n)
				p @keywords[url] if $debug
				# count words
				@keywords[url].split(" ").each{|word|
					@wordcount[word] += 1
				}
			}
		}
		output_wordcount(@wordcount) if $debug

		# strip low relationship news
		max_word = (@wordcount.sort{|a,b| a[1] <=> b[1]}[-1])[0]
		puts "<h2>Max count words:", max_word, "</h2>"
		puts "<h1>strip low relativity articles</h1>"
		puts "<ul>"
		STDERR << "\n"
		STDERR << "strip low relativity articles\n"
		@keywords.each{|url, words|
			STDERR << "."
			unless words.split(" ").include?(max_word)
				@contents.delete(url)
				output_content(url, "DELETE:" + @titles[url], @sources[url], @times[url].to_s, @contents[url], @wordcount, words)
				@contents.delete(url)
			end
		}
		puts "</ul>"

		# <<TODO>> sorting? or clustering? or make summary?
		puts "<h1>strip high similarity articles</h1>"
		puts "<ul>"
		STDERR << "\n"
		STDERR << "strip high similarity articles\n"
		@times.each{|source_url, source_time|
			STDERR << "."
			next unless @contents.has_key?(source_url)
			puts "<li>"
			@times.select{|url, time| source_time > time && time >= source_time - $time_frame}.each{|target_url, target_time|
				next unless @contents.has_key?(target_url)
				score = calc_score(source_url, target_url, @keywords)
				if (score > $score_threshold)
					p "SOURCE TIME:" + source_time.to_s if $debug
					p "TARGET_TIME:" + target_time.to_s if $debug
					puts "X" + @keywords[source_url].split(" ").length.to_s if $debug
					puts "Y" + @keywords[target_url].split(" ").length.to_s if $debug
					puts "M" + ( @keywords[source_url].split(" ") & @keywords[target_url].split(" ") ).length.to_s if $debug
					p "SCORE:" + score.to_s if $debug
					output_content2(target_url, "DELETE:" + @titles[target_url], @sources[target_url], @times[target_url].to_s, @contents[target_url], @wordcount, @keywords[target_url], score)
					@contents.delete(target_url)
				end
			}
			puts "</li>"
		}
		puts "</ul>"
		# <<TODO>> format for outout
		puts "<h1>news summary: Don't miss articles</h1>"
		puts "<ul>"
		STDERR << "\n"
		STDERR << "format for outout\n"
		@contents.each{|url, content|
			output_content(url, @titles[url], @sources[url], @times[url].to_s, content, @wordcount, @keywords[url])
		}
		puts "</ul>"
		output_footer()
	end
	
	def extract_links(url)
#		starttag = "<a name=\"ニュース\">"
#		endtag = "<!--■■■■■■■■■■■■■SQB■■■■■■■■■■■■■■■■-->"
		starttag = "<div id=\"detailNews\">"
		endtag = "<!--/detailNews-->"
		urls = Array.new()
		is_extract = false
	
		begin
			open(url, { :proxy => $proxy }){|file|
				while line = file.gets
					line = line.tosjis
					line.chomp!
					is_extract = false if Regexp.compile(endtag) =~ line
					line.scan(/http:\/\/[^"]+/){|url| urls.push(url)} if is_extract
					is_extract = true if Regexp.compile(starttag) =~ line
				end
			}
		rescue
			p $!
			return
		end
		# setting for Yahoo news?
		urls.find_all{|url| /yahoo/ =~ url}
	end
	private :extract_links
	
	def get_topics(url)
#		starttag = "<!---トピック名--->"
#		endtag = "<!---トピック名--->"
		starttag = "<!---======= /header =======--->"
		endtag = "<!-- 表示切り替えエリア -->"
		topics = ""
		is_extract = false
	
		begin
			open(url, { :proxy => $proxy }){|file|
				while line = file.gets
					line = line.tosjis
					line.chomp!
					is_extract = false if Regexp.compile(endtag) =~ line
					if is_extract
						# topics
#						if match = line.slice(/\<b\>([^\>]*)\<\/b\>/,1)
						if match = line.slice(/\<div class=\"hdH1\">\<h1 class=\"topicsName\"\>\<a href=\"([^\>]*)\"\>([^\>]*)\<\/a\>\<\/h1\>\<\/div\>/,2)
							topics = match
							break
						end
					end
					is_extract = true if Regexp.compile(starttag) =~ line
				end
			}
		rescue
			p $!
			return
		end
		topics
	end
	private :get_topics

	def strip_by_wordclass(n)
		n.find_all{|word|
			wordclass = word["wordclass"].split(",")
			wordclass[0] == "名詞" and wordclass[1] != "数" and wordclass[1] != "代名詞"
		}.collect{|word| word["surface"]}.join(" ")
	end
	private :strip_by_wordclass

	def calc_score(url1, url2, keywords)
		x = keywords[url1].split(" ").length
		y = keywords[url2].split(" ").length
		m = ( keywords[url1].split(" ") & keywords[url2].split(" ") ).length
		score = (m.to_f/x.to_f + m.to_f/y.to_f)/2 * 100
		return score
	end
	private :calc_score

	def reform(body, wordcount)
		return if body == nil
		wordcount.each{|key, value|
		#	p "#{key}:#{value}" if value.to_i >= 10
			body.gsub!(Regexp.compile(key), "<FONT size=\"+4\">#{key}</FONT>") if value.to_i >= 40
			body.gsub!(Regexp.compile(key), "<FONT size=\"+4\">#{key}</FONT>") if (value.to_i < 40 && value.to_i >= 30)
			body.gsub!(Regexp.compile(key), "<FONT size=\"+3\">#{key}</FONT>") if (value.to_i < 30 && value.to_i >= 20)
			body.gsub!(Regexp.compile(key), "<FONT size=\"+2\">#{key}</FONT>") if (value.to_i < 20 && value.to_i >= 10)
		}
		body
	end
	private :reform

	def output_header(topics, url)
		puts "<html>"
		puts "<head>", "<title>", "ニュース - ", topics, "</title>", "</head>"
		puts "<body>"
		puts "<h1>", "ニュース - ", topics, "</h1>"
		puts "<p><a href=", url, ">", "Yahoo!ニュースへジャンプ</a></p>"
	end
	private :output_header

	def output_footer()
		puts "</body></html>"
	end
	private :output_footer
	
	def output_content(url, title, source, time, content, count, words)
		puts "<li><a href=", url, ">", title
		puts "(", source, ")", "</a>"
		puts "<small>(", time, ")</small>"
		puts "</li><br>"
		puts reform(content, count)
		puts "<br>"
		puts "<small>words:", words, "</small><br>"
	end
	private :output_content

	def output_content2(url, title, source, time, content, count, words, score)
		puts "<li><a href=", url, ">", title
		puts "(", source, ")", "</a>"
		puts "<small>(", time, ")</small>"
		puts "</li><br>"
		puts reform(content, count)
		puts "<br>"
		puts "<small>words:", words, "</small><br>"
		puts "<small>score:", score, "</small><br>"
	end
	private :output_content2

	def output_wordcount(count)
		##output result
		count.sort{|a,b|
			a[1] <=> b[1]
		}.each{|key, value|
			print "#{key}: #{value}\n"
		}
	end
	private :output_wordcount

	# this method is only for method/liblary first test
	def NewsSummary.playingtest()
		# for MeCab test(install mecab library if it needs)
		# m = MeCab.new("-Ochasen")
		m = MeCab.new("")
		print m.parse("今日もしないとね")
		#m = MeCab.new("-O wakati")
		#p m.parse_file("test.txt")
	end

end

if $0 == __FILE__
  summary = NewsSummary.new()
  summary.process(ARGV, STDIN)
#  NewsSummary.playingtest()
end
