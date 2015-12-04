require 'rubygems'
require 'mechanize'
require 'csv'
require 'pry-byebug'
require 'optparse'


##### TODO #####
#
#   - Create an array for @search_form fields with strict index (e.g., fields = [ query, max_price, min_price, url, ... ] )
#       |-> In progress
#   - Parameterize program
#   - Include a warning that default website is used, if none passed to program
#   - Introduce 'usage' method (private?)
#   - Fix parameterization of 'save_results' method
#   - Use external file to map page elements to website
#   - Use hash/external file to map form fields to website
#   - Fix method comments (RE: Params/Returns)
#   - Fix error strings in argument validation
#   - Optional: optimizations (e.g., limit to certain radius)
#   - Optional: Add other configurations to 'init'

##### GLOBAL VARIABLES #####

# Hard-coded default address in case none provided
ADDRESS = 'http://kingston.craigslist.ca/search/apa'

##### SCRAPER CLASS #####

class Scraper

    def initialize(address=ADDRESS)
        @scraper = init()
        @website = address
        @search_form = nil
        @search_fields = []
        @search_results = []
    end ## initialize Method


    public

    ### --Retrieve and fill form-- ###
    #   Params: address - URL where search form is located
    #           scraper - Previously initialized Mechanize object
    #   Returns: Completed search form
    #   NOTE: May need to pass more arguments for search queries
    ###
    def fill_form
        # Validate argument variables
        raise "First argument of fill_form must be a Mechanize object" unless @scraper.respond_to?(:get)

        raise "Second argument of fill_form must be a String" unless @website.respond_to?(:to_str)

        # Begin scraping
        search_page = @scraper.get(@website.clone)

        # Work with the form. Used block to wrap all form fields in separate scope.
        form = search_page.form_with( :id => 'searchform' ) do |search|

            search.checkbox_with( :name => 'srchType' ).check
            search.checkbox_with( :name => 'hasPic' ).check
            search.checkbox_with( :name => 'postedToday' ).check
            search.checkbox_with( :name => 'searchNearby' ).check

            search.min_price = 0
            search.max_price = 1000

            search.field_with( :name => 'bedrooms' ).options[0].click
            search.field_with( :name => 'bathrooms' ).options[1].click

            search.minSqft = 0
            search.maxSqft = 1000000

            search.checkbox_with( :name => 'pets_cat' ).check
            search.checkbox_with( :name => 'pets_dog' ).check
            search.checkbox_with( :name => 'is_furnished' ).check
            search.checkbox_with( :name => 'no_smoking' ).check
            search.checkbox_with( :name => 'wheelchaccess' ).check

            search.checkbox_with( :id => 'apartment_1' ).check
            search.checkbox_with( :id => 'condo_2' ).check
            search.checkbox_with( :id => 'cottage/cabin_3' ).check
            search.checkbox_with( :id => 'duplex_4' ).check
            search.checkbox_with( :id => 'flat_5' ).check
            search.checkbox_with( :id => 'house_6' ).check
            search.checkbox_with( :id => 'in-law_7' ).check
            search.checkbox_with( :id => 'loft_8' ).check
            search.checkbox_with( :id => 'townhouse_9' ).check
            search.checkbox_with( :id => 'manufactured_10' ).check
            search.checkbox_with( :id => 'assisted_living_11' ).check
            search.checkbox_with( :id => 'land_12' ).check

            search.checkbox_with( :id => 'w/d_in_unit_1' ).check
            search.checkbox_with( :id => 'w/d_hookups_4' ).check
            search.checkbox_with( :id => 'laundry_in_bldg_2' ).check
            search.checkbox_with( :id => 'laundry_on_site_3' ).check
            search.checkbox_with( :id => 'no_laundry_on_site_5' ).check

            search.checkbox_with( :id => 'carport_1' ).check
            search.checkbox_with( :id => 'attached_garage_2' ).check
            search.checkbox_with( :id => 'detached_garage_3' ).check
            search.checkbox_with( :id => 'off-street_parking_4' ).check
            search.checkbox_with( :id => 'street_parking_5' ).check
            search.checkbox_with( :id => 'valet_parking_6' ).check
            search.checkbox_with( :id => 'no_parking_7' ).check

            search.field_with( :id => 'sale_date' ).options[0].click

            search.query = 'student'
        end

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

    ### --Parse Program Arguments-- ###
    #   Params: <none>
    #   Returns: <none>
    ###
    def parse_args
        options = {}
        OptionParser.new do |opt|
            opt.on('-t', '--title-only', 'Search for query in title only') { |b|
                options[:title_only] = b
            }

            opt.on('-q', '--query QUERY', 'Search for results that include QUERY') { |o|
                options[:query] = o
            }

            opt.on('-p', '--has-pic', 'Only show results with a picture') { |b|
                options[:has_pic] = b
            }

            opt.on('--posted-today', 'Only show results posted today') { |b|
                option[:posted_today] = b
            }

            opt.on('', '--nearby', 'Only show nearby results') { |b|
                option[:nearby] = b
            }

            opt.on('-min', '--min-price MIN_PRICE', 'Filter out results for less than MIN_PRICE') { |o|
                option[:min_price] = o
            }

            opt.on('-max', '--max-price MAX_PRICE', 'Filter out results for more than MAX_PRICE') { |o|
                option[:max_price] = o
            }

            opt.on('', '--bedrooms NUM', 'Filter out results with less than NUM bedrooms') { |o|
                option[:bedrooms] = o
            }

            opt.on('', '--bathrooms NUM', 'Filter out results with less than NUM bathrooms') { |o|
                option[:bathrooms] = o
            }

            opt.on('', '--min-sq-ft NUM', 'Filter out results with less than NUM square feet') { |o|
                option[:min_ft] = o
            }

            opt.on('', '--max-sq-ft NUM', 'Filter out results with more than NUM square feet') { |o|
                option[:max_ft] = o
            }

            opt.on('', '--allow-cat', 'Filter out results that do NOT allow cats') { |b|
                option[:pets_cat] = b
            }

            opt.on('', '--allow-dog', 'Filter out results that do NOT allow dogs') { |b|
                option[:pets_dog] = b
            }

            opt.on('-f', '--furnished', 'Filter out results that are NOT furnished') { |b|
                option[:furnished] = b
            }

            opt.on('-s', '--no-smoking', 'Filter out results that allow smoking') { |b|
                option[:no_smoking] = b
            }

            opt.on('-w', '--wheelchair', 'Filter out results that are NOT wheelchair accessible') { |b|
                option[:wheelchair] = b
            }

            #search.checkbox_with( :id => 'apartment_1' ).check
            #search.checkbox_with( :id => 'condo_2' ).check
            #search.checkbox_with( :id => 'cottage/cabin_3' ).check
            #search.checkbox_with( :id => 'duplex_4' ).check
            #search.checkbox_with( :id => 'flat_5' ).check
            #search.checkbox_with( :id => 'house_6' ).check
            #search.checkbox_with( :id => 'in-law_7' ).check
            #search.checkbox_with( :id => 'loft_8' ).check
            #search.checkbox_with( :id => 'townhouse_9' ).check
            #search.checkbox_with( :id => 'manufactured_10' ).check
            #search.checkbox_with( :id => 'assisted_living_11' ).check
            #search.checkbox_with( :id => 'land_12' ).check

            #search.checkbox_with( :id => 'w/d_in_unit_1' ).check
            #search.checkbox_with( :id => 'laundry_in_bldg_2' ).check
            #search.checkbox_with( :id => 'laundry_on_site_3' ).check
            #search.checkbox_with( :id => 'w/d_hookups_4' ).check
            #search.checkbox_with( :id => 'no_laundry_on_site_5' ).check

            #search.checkbox_with( :id => 'carport_1' ).check
            #search.checkbox_with( :id => 'attached_garage_2' ).check
            #search.checkbox_with( :id => 'detached_garage_3' ).check
            #search.checkbox_with( :id => 'off-street_parking_4' ).check
            #search.checkbox_with( :id => 'street_parking_5' ).check
            #search.checkbox_with( :id => 'valet_parking_6' ).check
            #search.checkbox_with( :id => 'no_parking_7' ).check

            opt.on('', '--open-house DATE', 'Filter results by open house date') { |o|
                options[:sale_date] = o
            }
        end
    end

end ## Scraper Class

##### OTHER METHODS #####
#   Current best-thinking:
#       - parse_args
#       - usage
#       - read_file


##### MAIN #####

c_list = Scraper.new()
c_list.fill_form.get_results.save_results

##### END #####
