
require 'rubygems'
require 'mechanize'
require 'csv'
require 'pry-byebug'

##### GLOBAL VARIABLES #####

# Hard-coded address for scraping
#   TODO: Change this to an argument-based variable
ADDRESS = 'http://kingston.craigslist.ca/search/apa'

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

    scraper
end

### --Retrieve and fill form-- ###
#   Params: address - URL where search form is located
#           scraper - Previously initialized Mechanize object
#   Returns: Completed search form
#   NOTE: May need to pass more arguments for search queries
###
def fill_form(scraper, address=ADDRESS)
    # Validate argument variables
    raise "First argument of fill_form must be a Mechanize object" unless scraper.respond_to?(:get)

    raise "Second argument of fill_form must be a String" unless address.respond_to?(:to_str)

    # Begin scraping
    search_page = scraper.get(address)

    # Work with the form
    #   TODO: Use an external file to store mappings of website to search-form
    #   id, result-tags, etc.
    form = search_page.form_with( :id => 'searchform' )

    #   TODO: Make query and other search parameters argument-based variables
    #search.query = 'student'
    #search.maxAsk = 0
    # Others...?

    form
end

### --Submit form and parse results-- ###
#   Params: form - form to submit to get parsable results
#   Returns: An array with results
###
def get_results(form)
    # Validate argument variables
    raise "Argument of get_results must be a web-page form" unless form.respond_to?(:submit)

    # Submit form to get results
    result_page = form.submit

    # Get results
    #   TODO: Determine unique identifier of search results
    raw_results = result_page.search('p.row')

    # Array to hold each of the elements in .csv file.
    #   TODO: Determine what fields are wanted/available
    results = []
    results << ['Name', 'URL', 'Price', 'Location']

    # Parse the results
    #   TODO: Determine best way to parse each of the required fields
    raw_results.each do |result|
        link = result.css('a')[1]
        name = link.text.strip  # result.link.text.strip
        url = "http://kingston.craigslist.ca" + link.attributes["href"].value   # result.link.attributes["href"].value
        price = result.search('span.price').text
        location = result.search('span.pnr').text

        #   TODO: Apply a filter based on street(?) to reduce number of postings

        # Save the results
        results << [name, url, price, location]
    end

    results
end

### --Save files-- ###
#   Params: *file - Any number of file names to save results to
#           results - Array containing results to be saved
#   Returns: <none>
###
def save_results(results, *file)
    # Validate argument variables
    raise "First argument of save_results must be an array" unless results.respond_to?(:each)

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

##### MAIN #####

clist_form = fill_form(init)

clist_results = get_results(clist_form)

save_results(clist_results)


##### END #####
