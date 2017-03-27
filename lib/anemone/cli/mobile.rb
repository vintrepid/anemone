require 'anemone'
require 'optparse'
require 'ostruct'
require 'cli-colorize'
require 'byebug'

options = OpenStruct.new
options.relative = false
options.output_file = 'urls.txt'

begin
  # make sure that the last argument is a URL we can crawl
  root = URI(ARGV.last)
rescue
  puts <<-INFO
Usage:
  anemone mobile [options] <url>

Synopsis:
  Combination of `count`, `pagedepth` and `url-list` commands.
  Performs pagedepth, url list, and count functionality.
  Outputs results to STDOUT and link list to file (urls.txt).
  Meant to be run daily as a cron job.

Options:
  -r, --relative           Output relative URLs (rather than absolute)
  -o, --output filename    Filename to save URL list to. Defautls to urls.txt.
INFO
  exit(0)
end

# parse command-line options
opts = OptionParser.new
opts.on('-r', '--relative')        { options.relative = true }
opts.on('-o', '--output filename') {|o| options.output_file = o }
opts.parse!(ARGV)

root_str = root.to_s

started_at = Time.now

puts "Starting mobile crawl at #{started_at}"

Anemone.crawl(root, {discard_page_bodies: true, user_agent: "iPhone",
accept_cookies: true}) do |anemone|

  anemone.focus_crawl do |page|
    page.links.reject do |link|
      (link.to_s.include?("/trip/") && link.to_s[-9..-1]=="/download") ||
       link.to_s.include?("/brochure/") ||
       link.to_s.include?("/kilimanjaro/") ||
       link.to_s.include?("/publish")
    end
  end

  anemone.on_every_page do |page|
    begin
      page_status = "#{page.code}  #{page.depth}  %4.2fs #{page.body.size.to_s.rjust(10,' ')} #{page.url.to_s.gsub(root_str,'')}" % (page.response_time.to_f / 1000)
    rescue
      page_status = "#{page.code}  #{page.depth}  #{(page.response_time.to_f / 1000)}s #{page.body.size.to_s.rjust(10,' ')} #{page.url.to_s.gsub(root_str,'')}"
    end
    page_status = page_status.blue if page.code >= 300 and page.code < 400
    page_status = page_status.red if page.code >= 400
    puts page_status
  end

  anemone.after_crawl do |pages|
    ended_at = Time.now

    puts "Mobile Crawl results for #{root}\n\n"
    puts "Mobile Crawl started at #{started_at}"
    puts "        ended at #{ended_at}"
    puts "Mobile Crawl took #{(ended_at - started_at) / 60} minutes..."

    # print a list of 404's
    not_found = []
    pages.each_value do |page|
      url = page.url.to_s
      not_found << url if page.not_found?
    end
    unless not_found.empty?
      puts "\n404's:"

      missing_links = pages.urls_linking_to(not_found)
      missing_links.each do |url, links|
        if options.relative
          puts URI(url).path.to_s
        else
          puts url
        end
        links.slice(0..10).each do |u|
          u = u.path if options.relative
          puts "  linked from #{u}"
        end
        
        puts " ... (and #{links.size - 11} more)" if links.size > 11
      end

      print "\n"
    end  

    # print a list of 301's
    redirected = []
    pages.each_value do |page|
      url = page.url.to_s
      redirected << url if page.redirect?
    end
    unless redirected.empty?
      puts "\n301's:"

      missing_links = pages.urls_linking_to(redirected)
      missing_links.each do |url, links|
        if options.relative
          puts URI(url).path.to_s
        else
          puts url
        end
        links.slice(0..10).each do |u|
          u = u.path if options.relative
          puts "  linked from #{u}"
        end
        
        puts " ... (and #{links.size - 11} more)" if links.size > 11
      end

      print "\n"
    end  

    # print a list of errors
    redirected = []
    pages.each_value do |page|
      url = page.url.to_s
      redirected << url if page.code >= 500
    end
    unless redirected.empty?
      puts "\nErrors:"

      missing_links = pages.urls_linking_to(redirected)
      missing_links.each do |url, links|
        if options.relative
          puts URI(url).path.to_s
        else
          puts url
        end
        links.slice(0..10).each do |u|
          u = u.path if options.relative
          puts "  linked from #{u}"
        end
        
        puts " ... (and #{links.size - 11} more)" if links.size > 11
      end

      print "\n"
    end  
    
    # remove redirect aliases, and calculate pagedepths
    pages = pages.shortest_paths!(root).uniq!
    depths = pages.values.inject({}) do |depths, page|
      depths[page.depth] ||= 0
      depths[page.depth] += 1
      depths
    end
    
    # print the page count
    puts "Total pages: #{pages.size}\n"
    
    # print a list of depths
    depths.sort.each { |depth, count| puts "Depth: #{depth} Count: #{count}" }
    
    # output a list of urls to file
    file = open(options.output_file, 'w')
    pages.each_value do |page|
      url = options.relative ? page.url.path.to_s : url.to_s
      file.puts url
    end
  end
end