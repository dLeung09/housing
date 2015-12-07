require 'rubygems'
require 'mechanize'
require 'csv'
require 'pry-byebug'
require 'optparse'
require 'date'


##### TODO #####
#
#   - Fix parameterization of 'save_results' method
#   - Create an array for @search_form fields with strict index (e.g., fields = [ query, max_price, min_price, url, ... ] )
#       |-> Complete
#       |-> Next Step: Optimize/refactor code
#   - Parameterize program
#       |-> Complete
#       |-> BUG: Multiple interactive sessions cause failure.
#           |--> Takes second interactive session tag as input to first interactive session.
#   - Sanitize program parameters
#   - Customize with 'Usage' message
#   - Include a warning that default website is used, if none passed to program
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
        @search_fields = {}
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

        @search_fields = parse_args

        # Work with the form. Used block to wrap all form fields in separate scope.
        form = search_page.form_with( :id => 'searchform' ) do |search|

            # Search query related
            search.query = @search_fields[:query] if @search_fields[:query]
            search.checkbox_with( :name => 'srchType' ).check if (@search_fields[:query] && @search_fields[:srch_type])

            # Check-box
            search.checkbox_with( :name => 'hasPic' ).check if @search_fields[:has_pic]
            search.checkbox_with( :name => 'postedToday' ).check if @search_fields[:posted_today]
            search.checkbox_with( :name => 'searchNearby' ).check if @search_fields[:search_nearby]

            search.checkbox_with( :name => 'pets_cat' ).check if @search_fields[:pets_cat]
            search.checkbox_with( :name => 'pets_dog' ).check if @search_fields[:pets_dog]
            search.checkbox_with( :name => 'is_furnished' ).check if @search_fields[:is_furnished]
            search.checkbox_with( :name => 'no_smoking' ).check if @search_fields[:no_smoking]
            search.checkbox_with( :name => 'wheelchaccess' ).check if @search_fields[:wheelch_access]

            # Fill-able fields
            search.min_price = @search_fields[:min_price] if @search_fields[:min_price]
            search.max_price = @search_fields[:max_price] if @search_fields[:max_price]

            search.minSqft = @search_fields[:min_sq_ft] if @search_fields[:min_sq_ft]
            search.maxSqft = @search_fields[:max_sq_ft] if @search_fields[:max_sq_ft]

            # Drop-down menus
            if (@search_fields[:bedrooms])
                num_beds = Integer(@search_fields[:bedrooms])
                search.field_with( :name => 'bedrooms' ).options[num_beds].click if num_beds > 0
            end

            if (@search_fields[:bathrooms])
                num_baths = Integer(@search_fields[:bathrooms])
                search.field_with( :name => 'bathrooms' ).options[num_baths].click if num_baths > 0
            end

            if (@search_fields[:sale_date])
                sale_date = @search_fields[:sale_date]
                search.field_with( :id => 'sale_date' ).options[sale_date].click
            end

            # Multiple selection checkbox
            if @search_fields[:housing_type]
                completion_flag = false
                lower_hash = {}

                puts <<-EOS
    Type the number of each housing-type that should be included in the search, and press <Enter>.
    Type "0" when done.

        1  - Apartment
        2  - Condo
        3  - Cottage/Cabin
        4  - Duplex
        5  - Flat
        6  - House
        7  - In-Law
        8  - Loft
        9  - Townhouse
        10 - Manufactured
        11 - Assisted Living
        12 - Land
        0  - DONE
EOS
                until completion_flag do
                    print 'Select -> '
                    input = gets.to_i

                    case input
                    when 0

                        completion_flag = true

                        lower_hash.each do |type, value|
                            model = type.to_s
                            model.gsub!(/_/, ' ') if model =~ /_/
                            model.capitalize!
                            puts "#{model} selected."
                        end

                    when 1
                        lower_hash[:apartment] = true
                        search.checkbox_with( :id => 'apartment_1' ).check
                    when 2
                        lower_hash[:condo] = true
                        search.checkbox_with( :id => 'condo_2' ).check
                    when 3
                        lower_hash[:cottage_cabin] = true
                        search.checkbox_with( :id => 'cottage/cabin_3' ).check
                    when 4
                        lower_hash[:duplex] = true
                        search.checkbox_with( :id => 'duplex_4' ).check
                    when 5
                        lower_hash[:flat] = true
                        search.checkbox_with( :id => 'flat_5' ).check
                    when 6
                        lower_hash[:house] = true
                        search.checkbox_with( :id => 'house_6' ).check
                    when 7
                        lower_hash[:in_law] = true
                        search.checkbox_with( :id => 'in-law_7' ).check
                    when 8
                        lower_hash[:loft] = true
                        search.checkbox_with( :id => 'loft_8' ).check
                    when 9
                        lower_hash[:townhouse] = true
                        search.checkbox_with( :id => 'townhouse_9' ).check
                    when 10
                        lower_hash[:manufactured] = true
                        search.checkbox_with( :id => 'manufactured_10' ).check
                    when 11
                        lower_hash[:assisted_living] = true
                        search.checkbox_with( :id => 'assisted_living_11' ).check
                    when 12
                        lower_hash[:land] = true
                        search.checkbox_with( :id => 'land_12' ).check
                    else
                        puts <<-EOS
Invalid input.

    1  - Apartment
    2  - Condo
    3  - Cottage/Cabin
    4  - Duplex
    5  - Flat
    6  - House
    7  - In-Law
    8  - Loft
    9  - Townhouse
    10 - Manufactured
    11 - Assisted Living
    12 - Land
    0  - DONE
EOS
                    end
                end
            end

            if @search_fields[:laundry]
                completion_flag = false
                lower_hash = {}

                puts <<-EOS
    Type the number of each laundry options that should be included in the search, and press <Enter>.
    Type "0" when done.

        1  - W/D in Unit
        2  - Laundry in Building
        3  - Laundry on Site
        4  - W/D Hookups
        5  - No Laundry on Site
        0  - DONE
EOS
                until completion_flag do
                    print 'Select -> '
                    input = gets.to_i

                    case input
                    when 0

                        completion_flag = true

                        lower_hash.each do |type, value|
                            model = type.to_s
                            model.gsub!(/_/, ' ') if model =~ /_/
                            model.capitalize!
                            puts "#{model} selected."
                        end

                    when 1
                        lower_hash[:w_d_in_unit] = true
                        search.checkbox_with( :id => 'w/d_in_unit_1' ).check
                    when 2
                        lower_hash[:laundry_in_bldg] = true
                        search.checkbox_with( :id => 'laundry_in_bldg_2' ).check
                    when 3
                        lower_hash[:laundry_on_site] = true
                        search.checkbox_with( :id => 'laundry_on_site_3' ).check
                    when 4
                        lower_hash[:w_d_hookups] = true
                        search.checkbox_with( :id => 'w/d_hookups_4' ).check
                    when 5
                        lower_hash[:no_laundry_on_site] = true
                        search.checkbox_with( :id => 'no_laundry_on_site_5' ).check
                    else
                        puts <<-EOS
Invalid input.

    1  - W/D in Unit
    2  - Laundry in Building
    3  - Laundry on Site
    4  - W/D Hookups
    5  - No Laundry on Site
    0  - DONE
EOS
                    end
                end
            end

            if @search_fields[:parking]
                completion_flag = false
                lower_hash = {}

                puts <<-EOS
    Type the number of each parking options that should be included in the search, and press <Enter>.
    Type "0" when done.

    1  - Carport
    2  - Attached Garage
    3  - Detached Garage
    4  - Off-Street Parking
    5  - Street Parking
    6  - Valet Parking
    7  - No Parking
    0  - DONE
EOS
                until completion_flag do
                    print 'Select -> '
                    input = gets.to_i

                    case input
                    when 0

                        completion_flag = true

                        lower_hash.each do |type, value|
                            model = type.to_s
                            model.gsub!(/_/, ' ') if model =~ /_/
                            model.capitalize!
                            puts "#{model} selected."
                        end

                    when 1
                        lower_hash[:carport] = true
                        search.checkbox_with( :id => 'carport_1' ).check
                    when 2
                        lower_hash[:attached_garage] = true
                        search.checkbox_with( :id => 'attached_garage_2' ).check
                    when 3
                        lower_hash[:detached_garage] = true
                        search.checkbox_with( :id => 'detached_garage_3' ).check
                    when 4
                        lower_hash[:off_street_parking] = true
                        search.checkbox_with( :id => 'off-street_parking_4' ).check
                    when 5
                        lower_hash[:street_parking] = true
                        search.checkbox_with( :id => 'street_parking_5' ).check
                    when 6
                        lower_hash[:valet_parking] = true
                        search.checkbox_with( :id => 'valet_parking_6' ).check
                    when 7
                        lower_hash[:no_parking] = true
                        search.checkbox_with( :id => 'no_parking_7' ).check
                    else
                        puts <<-EOS
Invalid input.

    1  - Carport
    2  - Attached Garage
    3  - Detached Garage
    4  - Off-Street Parking
    5  - Street Parking
    6  - Valet Parking
    7  - No Parking
    0  - DONE
EOS
                    end
                end
            end
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
    #   Returns: Hash filled with search parameters.
    ###
    def parse_args
        options = {}

        OptionParser.new do |opt|
            opt.on('-c', '--allow-cat', 'Filter out results that do NOT allow cats') { |b|
                options[:pets_cat] = b
            }

            opt.on('-d', '--allow-dog', 'Filter out results that do NOT allow dogs') { |b|
                options[:pets_dog] = b
            }

            opt.on('-f', '--furnished', 'Filter out results that are NOT furnished') { |b|
                options[:is_furnished] = b
            }

            opt.on('-h', '--help', 'Show this help message') { puts opt; exit }

            opt.on('-p', '--has-pic', 'Only show results with a picture') { |b|
                options[:has_pic] = b
            }

            opt.on('-q', '--query QUERY', 'Search for results that include QUERY') { |o|
                options[:query] = o
            }

            opt.on('-s', '--no-smoking', 'Filter out results that allow smoking') { |b|
                options[:no_smoking] = b
            }

            opt.on('-t', '--title-only', 'Search for query in title only') { |b|
                options[:srch_type] = b
            }

            opt.on('-w', '--wheelchair', 'Filter out results that are NOT wheelchair accessible') { |b|
                options[:wheelch_acces] = b
            }

            opt.on('--bathrooms NUM', 'Filter out results with less than NUM bathrooms') { |o|
                unless o.is_a? Numeric
                    puts 'NUM must be a number.'
                    puts opt
                    exit
                end

                o = Integer(o)
                if (o < 0 || o > 8)
                    puts 'NUM must be between 0 and 8 (inclusive).'
                    puts opt
                    exit
                end

                options[:bathrooms] = o
            }

            opt.on('--bedrooms NUM', 'Filter out results with less than NUM bedrooms') { |o|
                unless o.is_a? Numeric
                    puts 'NUM must be a number.'
                    puts opt
                    exit
                end

                o = Integer(o)
                if (o < 0 || o > 8)
                    puts 'NUM must be between 0 and 8 (inclusive).'
                    puts opt
                    exit
                end

                options[:bedrooms] = o
            }

            opt.on('--min-price MIN_PRICE', 'Filter out results for less than MIN_PRICE') { |o|
                unless o.is_a? Numeric
                    puts 'MIN_PRICE must be a number.'
                    puts opt
                    exit
                end

                options[:min_price] = o
            }

            opt.on('--max-price MAX_PRICE', 'Filter out results for more than MAX_PRICE') { |o|
                unless o.is_a? Numeric
                    puts 'MAX_PRICE must be a number.'
                    puts opt
                    exit
                end

                options[:max_price] = o
            }

            opt.on('--min-sq-ft NUM', 'Filter out results with less than NUM square feet') { |o|
                unless o.is_a? Numeric
                    puts 'NUM must be a number.'
                    puts opt
                    exit
                end

                options[:min_sq_ft] = o
            }

            opt.on('--max-sq-ft NUM', 'Filter out results with more than NUM square feet') { |o|
                unless o.is_a? Numeric
                    puts 'NUM must be a number.'
                    puts opt
                    exit
                end

                options[:max_sq_ft] = o
            }

            opt.on('--nearby', 'Only show nearby results') { |b|
                options[:search_nearby] = b
            }

            opt.on('--posted-today', 'Only show results posted today') { |b|
                options[:posted_today] = b
            }

            opt.on('--open-house YYYY-MM-DD', 'Filter results by open house date') { |o|
                sale_date = o

                if sale_date =~ /(\d{4})-(\d{1,2})-(\d{1,2})/
                    year = Integer($1)
                    month = Integer($2)
                    day = Integer($3)
                else
                    puts 'Incorrect Date format.'
                    puts opt
                    exit
                end

                date = Date.new(year, month, day)
                current = Date.today
                sale_date = (date - current).to_i

                if sale_date < 0 || sale_date >= 28
                    puts 'Date outside valid range.'
                    puts opt
                    exit
                end

                options[:sale_date] = sale_date
            }

            opt.on('--housing-type', 'Opens an interactive session to filter search results by housing type') { |b|
                options[:housing_type] = b
            }

            opt.on('--laundry', 'Opens an interactive session to filter search results by laundry options') { |b|
                options[:laundry] = b
            }

            opt.on('--parking', 'Opens an interactive session to filter search results by parking options') { |b|
                options[:laundry] = b
            }
        end.parse!

        options
    end ## parse_args Method

end ## Scraper Class

##### OTHER METHODS #####
#   Current best-thinking:
#       - read_file


##### MAIN #####

c_list = Scraper.new()
c_list.fill_form.get_results.save_results

##### END #####
