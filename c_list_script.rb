require 'rubygems'
require 'mechanize'
require 'csv'
require 'pry-byebug'

# Mechanize library used for scraping results
scraper = Mechanize.new

# Mechanize setup to rate limit your scraping to once every half-second
scarper.history_added = Proc.new { sleep 0.5 }

# Hard-coded address for scraping
#   TODO: Change this to an argument-based variable
ADDRESS = ''

# Array to hold each of the elements in .csv file.
#   TODO: Determine what fields are wanted/available
results = []
results << ['Name', 'URL', 'Price', 'Location']

# Begin scraping
scraper.get(ADDRESS) do |search_page|

    # Work with the form
    #   TODO: Determine unique identifier of search form
    form = search_page.form_with(:id => '') do |search|
        #   TODO: Make query and other search parameters argument-based variables
        search.query = ''
        search.maxAsk = 0
        # Others...?
    end
    # Submit form to get results
    result_page = form.submit

    # Get results
    #   TODO: Determine unique identifier of search results
    raw_results = result_page.search('')

    # Parse the results
    #   TODO: Determine best way to parse each of the required fields
    raw_results.each do |result|
        #link = result.css('a')[1]

        #name = link.text.strip
        #url = "http://sfbay.craigslist.org" _ link.attributes["href"].value
        #price = result.search('span.price').text[3..13]

        # Save the results
        results << [name, url, price, location]
    end
end
