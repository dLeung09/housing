require 'rubygems'
require 'mechanize'
require 'csv'
require 'pry-byebug'

##### TODO #####
#
#   - Parameterize program
#   - Include a warning that default website is used, if none passed to program
#   - Introduce 'usage' method (private?)
#   - Fix parameterization of 'save_results' method
#   - Create an array for @search_form fields with strict index (e.g., fields = [ query, max_price, min_price, url, ... ] )
#   - Use external file to map page elements to website
#   - Use hash/external file to map form fields to website
#   - Fix method comments (RE: Params/Returns)
#   - Fix error strings in argument validation
#   - Optional optimizations (e.g., limit to certain radius)

##### GLOBAL VARIABLES #####

# Hard-coded default address in case none provided
ADDRESS = 'http://kingston.craigslist.ca/search/apa'

##### SCRAPER CLASS #####

class Scraper

    def initialize(address=ADDRESS)
        @scraper = init()
        @website = address
        @search_form = nil
        @search_results = []
    end ## initialize Method


    public

    ### --Retrieve and fill form-- ###
    #   Params: address - URL where search form is located
    #           scraper - Previously initialized Mechanize object
    #   Returns: Completed search form
    #   NOTE: May need to pass more arguments for search queries
    ###
    #def fill_form(scraper, address=ADDRESS)
    def fill_form
        # Validate argument variables
        raise "First argument of fill_form must be a Mechanize object" unless @scraper.respond_to?(:get)

        raise "Second argument of fill_form must be a String" unless @website.respond_to?(:to_str)

        # Begin scraping
        search_page = @scraper.get(@website.clone)

        # Work with the form
        form = search_page.form_with( :id => 'searchform' )

        #search.query = 'student'
        #search.maxAsk = 0
        # Others...?

        @search_form = form
        self
    end ## fill_form Method


    ### --Submit form and parse results-- ###
    #   Params: form - form to submit to get parsable results
    #   Returns: An array with results
    ###
    #def get_results(form)
    def get_results()
        # Validate argument variables
        raise "Argument of get_results must be a web-page form" unless @search_form.respond_to?(:submit)

        # Submit form to get results
        result_page = @search_form.submit

        # Get results
        raw_results = result_page.search('p.row')

        # Array to hold each of the elements in .csv file.
        results = []
        results << ['Name', 'URL', 'Price', 'Location']

        # Parse the results
        raw_results.each do |result|
            link = result.css('a')[1]
            name = link.text.strip  # result.link.text.strip
            url = "http://kingston.craigslist.ca" + link.attributes["href"].value   # result.link.attributes["href"].value
            price = result.search('span.price').text
            location = result.search('span.pnr').text

            # Save the results
            results << [name, url, price, location]
        end

        @search_results = results
        self
    end ## get_results Method

    ### --Save files-- ###
    #   Params: *file - Any number of file names to save results to
    #           results - Array containing results to be saved
    #   Returns: <none>
    ###
    #def save_results(results, *file)
    def save_results(*file)
        # Validate argument variables
        raise "First argument of save_results must be an array" unless @search_results.respond_to?(:each)

        CSV.open("test_output.csv", "w+") do |csv_file|
            @search_results.each do |row|
                csv_file << row
            end
        end

        File.open("text_output.txt", "w+") do |txt_file|
            @search_results.each do |row|
                name = row[0]
                url = row[1]
                price = row[2]
                location = row[3]
                txt_file << "Name: #{name}\n\tURL: #{url}\n\tPrice: #{price}\n\tLocation: #{location}\n\n"
            end
        end
    end


    private

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
    end ## init Method

end ## Scraper Class

##### MAIN #####

c_list = Scraper.new()
c_list.fill_form.get_results.save_results

##### END #####
