require 'rubygems'
require 'mechanize'
require 'csv'
require 'pry-byebug'
require 'optparse'
require 'date'


##### TODO #####
#
#   - Fix parameterization of 'save_results' method
#   - Refactor @search_fields building
#       |-> Building hash (Complete)
#       |-> Fill in form (In Progress)
#   - Sanitize program parameters
#   - Customize with 'Usage' message
#   - Include a warning that default website is used, if none passed to program
#       |-> Make optional parameter for website
#       |-> Check for valid website
#   - Use external file to map page elements to website
#       |-> Read file into arrays
#       |-> Introduce arguments to associated functions
#   - Use hash/external file to map form fields to website
#   - Extend to multiple sites
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
    #   Params: <none>
    #   Returns: Completed search form
    ###
    def fill_form
        # Validate argument variables
        raise "Mechanize object not initialized properly." unless @scraper.respond_to?(:get)

        raise "Please specify a valid website URL." unless @website.respond_to?(:to_str)

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
    #   Params: <none>
    #   Returns: An array with results
    ###
    def get_results()
        # Validate argument variables
        raise "Search form is invalid!" unless @search_form.respond_to?(:submit)

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

    ### --Build Hash for Boolean Flag Arguments-- ###
    #   Params: <none>
    #   Returns: Hash filled with syntax details for boolean flags.
    ###
    def build_bool_flags
        full_hash = {}
        temp = {}

        temp[:short] = '-c'
        temp[:long] = '--allow-cat'
        temp[:desc] = 'Filter out results that do NOT allow cats'

        full_hash[:pets_cat] = temp.clone

        temp[:short] = '-d'
        temp[:long] = '--allow-dog'
        temp[:desc] = 'Filter out results that do NOT allow dogs'

        full_hash[:pets_dog] = temp.clone

        temp[:short] = '-f'
        temp[:long] = '--furnished'
        temp[:desc] = 'Filter out results that are NOT furnished'

        full_hash[:is_furnished] = temp.clone

        temp[:short] = '-p'
        temp[:long] = '--has-pic'
        temp[:desc] = 'Only show results with a picture'

        full_hash[:has_pic] = temp.clone

        temp[:short] = '-q'
        temp[:long] = '--query QUERY'
        temp[:desc] = 'Search for results that include QUERY'

        full_hash[:query] = temp.clone

        temp[:short] = '-s'
        temp[:long] = '--no-smoking'
        temp[:desc] = 'Filter out results that allow smoking'

        full_hash[:no_smoking] = temp.clone

        temp[:short] = '-t'
        temp[:long] = '--title-only'
        temp[:desc] = 'Search for query in title only'

        full_hash[:srch_type] = temp.clone

        temp[:short] = '-w'
        temp[:long] = '--wheelchair'
        temp[:desc] = 'Filter out results that are NOT wheelchair accessible'

        full_hash[:wheelch_access] = temp.clone

        temp[:short] = nil
        temp[:long] = '--nearby'
        temp[:desc] = 'Only show nearby results'

        full_hash[:search_nearby] = temp.clone

        temp[:short] = nil
        temp[:long] = '--posted-today'
        temp[:desc] = 'Only show results posted today'

        full_hash[:posted_today] = temp.clone

        temp[:short] = nil
        temp[:long] = '--housing-type'
        temp[:desc] = 'Opens an interactive session to filter search results by housing type'

        full_hash[:housing_type] = temp.clone

        temp[:short] = nil
        temp[:long] = '--laundry'
        temp[:desc] = 'Opens an interactive session to filter search results by laundry options'

        full_hash[:laundry] = temp.clone

        temp[:short] = nil
        temp[:long] = '--parking'
        temp[:desc] = 'Opens an interactive session to filter search results by parking options'

        full_hash[:parking] = temp.clone

        full_hash
    end ## build_bool_flags Method

    ### --Build Hash for Input Flag Arguments-- ###
    #   Params: <none>
    #   Returns: Hash filled with syntax details for flags that require immediate input.
    ###
    def build_input_flags
        full_hash = {}
        temp = {}

        temp[:tag] = '--bathrooms NUM'
        temp[:desc] = 'Filter out results with less than NUM bathrooms'
        temp[:range_low] = '0'
        temp[:range_high] = '8'
        temp[:var] = 'NUM'

        full_hash[:bathrooms] = temp.clone

        temp[:tag] = '--bedrooms NUM'
        temp[:desc] = 'Filter out results with less than NUM bedrooms'
        temp[:range_low] = '0'
        temp[:range_high] = '8'
        temp[:var] = 'NUM'

        full_hash[:bedrooms] = temp.clone

        temp[:tag] = '--min-price MIN_PRICE'
        temp[:desc] = 'Filter out results for less than MIN_PRICE'
        temp[:range_low] = nil
        temp[:range_high] = nil
        temp[:var] = 'MIN_PRICE'

        full_hash[:min_price] = temp.clone

        temp[:tag] = '--max-price MAX_PRICE'
        temp[:desc] = 'Filter out results for more than MAX_PRICE'
        temp[:range_low] = nil
        temp[:range_high] = nil
        temp[:var] = 'MAX_PRICE'

        full_hash[:max_price] = temp.clone

        temp[:tag] = '--min-sq-ft NUM'
        temp[:desc] = 'Filter out results with less than NUM square feet'
        temp[:range_low] = nil
        temp[:range_high] = nil
        temp[:var] = 'NUM'

        full_hash[:min_sq_ft] = temp.clone

        temp[:tag] = '--max-sq-ft NUM'
        temp[:desc] = 'Filter out results with more than NUM square feet'
        temp[:range_low] = nil
        temp[:range_high] = nil
        temp[:var] = 'NUM'

        full_hash[:max_sq_ft] = temp.clone

        full_hash
    end # build_input_flags Method

    ### --Parse Program Arguments-- ###
    #   Params: <none>
    #   Returns: Hash filled with search parameters.
    ###
    def parse_args
        options = {}
        bool_flags = build_bool_flags
        input_flags = build_input_flags

        OptionParser.new do |opt|

            opt.on('-h', '--help', 'Show this help message') { puts opt; exit }

            bool_flags.each do |key, lower_hash|
                long = lower_hash[:long]
                desc = lower_hash[:desc]

                if lower_hash[:short]
                    short = lower_hash[:short]
                    opt.on("#{short}", "#{long}", "#{desc}") { |b|
                        options[key] = b
                    }
                else
                    opt.on("#{long}", "#{desc}") { |b|
                        options[key] = b
                    }

                end
            end

            input_flags.each do |key, lower_hash|
                tag = lower_hash[:tag]
                desc = lower_hash[:desc]
                var = lower_hash[:var]

                opt.on("#{tag}", "#{desc}") { |o|
                    unless /\A[+-]?\d+\z/.match(o)
                        puts "#{var} must be a integer."
                        puts opt
                        exit
                    end

                    o = Integer(o)

                    if (lower_hash[:range_low] && lower_hash[:range_high])
                        range_low = lower_hash[:range_low]
                        range_high = lower_hash[:range_high]
                            if (o < range_low || o > range_high)
                                puts "#{var} must be between #{range_low} and #{range_high} (inclusive)."
                                puts opt
                                exit
                            end
                    elsif (lower_hash[:range_low])
                        range_low = lower_hash[:range_low]
                            if (o < range_low)
                                puts "#{var} must be less than #{range_low}."
                                puts opt
                                exit
                            end
                    elsif (lower_hash[:range_high])
                        range_high = lower_hash[:range_high]
                            if (o > range_high)
                                puts "#{var} must be less than #{range_high}."
                                puts opt
                                exit
                            end
                    end

                    options [key] = o
                }
            end

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
