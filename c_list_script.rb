require 'rubygems'
require 'mechanize'
require 'csv'
require 'pry-byebug'

##### GLOBAL VARIABLES #####

# Hard-coded address for scraping
#   TODO: Change this to an argument-based variable
ADDRESS = 'http://kingston.craigslist.ca/search/apa'

# Array to hold each of the elements in .csv file.
#   TODO: Determine what fields are wanted/available
results = []
results << ['Name', 'URL', 'Price', 'Location']

##### METHODS #####

### --Initialize Mechanize-- ###
#   Params: <none>
#   Returns: Initialized Mechanize with preferred configuration
###
def init
    # Mechanize library used for scraping results
    scraper = Mechanize.new

    # Mechanize setup to rate limit your scraping to once every half-second
    scraper.history_added = Proc.new { sleep 0.5 }
end

### --Retrieve and fill form-- ###
#   Params: address - URL where search form is located
#   Returns: Completed search form
#   NOTE: May need to pass more arguments for search queries
###
def fill_form(address=ADDRESS)
    # Begin scraping
    search_page = scraper.get(ADDRESS)

    # Work with the form
    form = search_page.form_with( :id => 'searchform' )

    #   TODO: Make query and other search parameters argument-based variables
    #search.query = 'student'
    #search.maxAsk = 0
    # Others...?
end

### --Submit form and parse results-- ###
#   Params: form - form to submit to get parsable results
#   Returns: An array with results
###
def get_results(form)
    # Submit form to get results
    result_page = form.submit

    # Get results
    #   TODO: Determine unique identifier of search results
    raw_results = result_page.search('p.row')

    # Parse the results
    #   TODO: Determine best way to parse each of the required fields
    raw_results.each do |result|
        link = result.css('a')[1]
        name = link.text.strip
        url = "http://kingston.craigslist.ca" + link.attributes["href"].value
        price = result.search('span.price').text
        location = result.search('span.pnr').text

        #   TODO: Apply a filter based on street(?) to reduce number of postings

        # Save the results
        results << [name, url, price, location]
    end
end

### --Save files-- ###
#   Params: *file - Any number of file names to save results to
#   Returns: <none>
###
def save_results(*file)
    CSV.open("test_output.csv", "w+") do |csv_file|
        results.each do |row|
            csv_file << row
        end
    end

    #   TODO: Save to a human readable format (.txt?) as well
    File.open("text_output.txt", "w+") do |txt_file|
        results.each do |row|
            name = row[0]
            url = row[1]
            price = row[2]
            location = row[3]
            txt_file << "Name: #{name}\n\tURL: #{url}\n\tPrice: #{price}\n\tLocation: #{location}\n\n"
        end
    end
end

##### END #####
