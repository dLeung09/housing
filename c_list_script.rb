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
#       |-> Fill in form (Complete*)  - *Testing still required*
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
        @search_results = []
        @checkbox_fields = {}
        @fill_fields = {}
        @drop_fields = {}
        @mult_fields = {}
        @query= {}
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

        parse_args

        # Work with the form. Used block to wrap all form fields in separate scope.
        form = search_page.form_with( :id => 'searchform' ) do |search|

            # Search query related
            search.query = @query[:query] if @query[:query]
            search.checkbox_with( :name => 'srchType' ).check if (@query[:query] && @query[:srch_type])

            # Check-box
            @checkbox_fields.each do |key, value|
                search.checkbox_with( :name => key.to_s ).check
            end

            # Fill-able fields
            @fill_fields.each do |key, value|
                search.field_with( :name => key.to_s ).value = value
            end

            # Drop-down menus
            @drop_fields.each do |key, value|
               search.field_with( :name => key.to_s ).options[value].click
            end

            # Multiple selection checkbox
            @mult_fields.each do |key, hash|
                completion_flag = false
                lower_hash = {}
                type = key.to_s.gsub(/_/, '-') if key.to_s.match (/_/)
                array = hash[:array]

                isession_help(type, array)

                until completion_flag do
                    print 'Select -> '
                    input = gets.chomp!
                    unless /\A[+-]?\d+\z/.match(input)
                        puts 'Input must be an integer!'
                        isession_help(type, array)
                        next
                    end

                    input = input.to_i

                    if input == 0
                        completion_flag = true

                        lower_hash.each do |type, value|
                            model = type.to_s
                            model.gsub!(/_/, ' ') if model =~ /_/
                            model.capitalize!
                            puts "#{model} selected."
                        end
                    elsif (input > 0 && input < array.length)
                        index = input - 1
                        inner_hash = array[index]
                        inner_hash.each do |symbol, string| # Should only be one key-value pair
                            lower_hash[symbol] = true
                            search.checkbox_with( :id => symbol.to_s ).check
                        end
                    else
                        puts "Invalid entry\n"
                        isession_help(type, array)
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
        temp[:hash] = :checkbox
        temp[:sym_hash] = nil

        full_hash[:pets_cat] = temp.clone

        temp[:short] = '-d'
        temp[:long] = '--allow-dog'
        temp[:desc] = 'Filter out results that do NOT allow dogs'
        temp[:hash] = :checkbox
        temp[:sym_hash] = nil

        full_hash[:pets_dog] = temp.clone

        temp[:short] = '-f'
        temp[:long] = '--furnished'
        temp[:desc] = 'Filter out results that are NOT furnished'
        temp[:hash] = :checkbox
        temp[:sym_hash] = nil

        full_hash[:is_furnished] = temp.clone

        temp[:short] = '-p'
        temp[:long] = '--has-pic'
        temp[:desc] = 'Only show results with a picture'
        temp[:hash] = :checkbox
        temp[:sym_hash] = nil

        full_hash[:hasPic] = temp.clone

        temp[:short] = '-q'
        temp[:long] = '--query QUERY'
        temp[:desc] = 'Search for results that include QUERY'
        temp[:hash] = :query
        temp[:sym_hash] = nil

        full_hash[:query] = temp.clone

        temp[:short] = '-s'
        temp[:long] = '--no-smoking'
        temp[:desc] = 'Filter out results that allow smoking'
        temp[:hash] = :checkbox
        temp[:sym_hash] = nil

        full_hash[:no_smoking] = temp.clone

        temp[:short] = '-t'
        temp[:long] = '--title-only'
        temp[:desc] = 'Search for query in title only'
        temp[:hash] = :query
        temp[:sym_hash] = nil

        full_hash[:srchType] = temp.clone

        temp[:short] = '-w'
        temp[:long] = '--wheelchair'
        temp[:desc] = 'Filter out results that are NOT wheelchair accessible'
        temp[:hash] = :checkbox
        temp[:sym_hash] = nil

        full_hash[:wheelchaccess] = temp.clone

        temp[:short] = nil
        temp[:long] = '--nearby'
        temp[:desc] = 'Only show nearby results'
        temp[:hash] = :checkbox
        temp[:sym_hash] = nil

        full_hash[:searchNearby] = temp.clone

        temp[:short] = nil
        temp[:long] = '--posted-today'
        temp[:desc] = 'Only show results posted today'
        temp[:hash] = :checkbox
        temp[:sym_hash] = nil

        full_hash[:postedToday] = temp.clone

        temp[:short] = nil
        temp[:long] = '--housing-type'
        temp[:desc] = 'Opens an interactive session to filter search results by housing type'
        temp[:hash] = :mult

        sym_hash = [{:apartment_1 => 'Apartment'}, {:condo_2 => 'Condo'},
                    {'cottage/cabin_3'.to_sym => 'Cottage/Cabin'}, {:duplex_4 => 'Duplex'},
                    {:flat_5 => 'Flat'}, {:house_6 => 'House'}, {'in-law_7'.to_sym => 'In-Law'},
                    {:loft_8 => 'Loft'}, {:townhouse_9 => 'Townhouse'},
                    {:manufactured_10 => 'Manufactured'}, {:assisted_living_11 => 'Assisted Living'},
                    {:land_12 => 'Land'}]

        temp[:sym_hash] = sym_hash.clone

        full_hash[:housing_type] = temp.clone

        temp[:short] = nil
        temp[:long] = '--laundry'
        temp[:desc] = 'Opens an interactive session to filter search results by laundry options'
        temp[:hash] = :mult

        sym_hash = [{'w/d_in_unit_1'.to_sym => 'W/D in Unit'}, {:laundry_in_bldg_2 => 'Laundry in Building'},
                    {:laundry_on_site_3 => 'Laundry on Site'}, {'w/d_hookups_4'.to_sym => 'W/D Hookups'},
                    {:no_laundry_on_site_5 => 'No Laundry on Site'}]

        temp[:sym_hash] = sym_hash.clone

        full_hash[:laundry] = temp.clone

        temp[:short] = nil
        temp[:long] = '--parking'
        temp[:desc] = 'Opens an interactive session to filter search results by parking options'
        temp[:hash] = :mult

        sym_hash = [{:carport_1 => 'Carport'}, {:attached_garage_2 => 'Attached Garage'},
                    {:detached_garage_3 => 'Detached_Garage'},
                    {'off-street_parking_4'.to_sym => 'Off-Street Parking'},
                    {:street_parking_5 => 'Street Parking'}, {:valet_parking_6 => 'Valet Parking'},
                    {:no_parking_7 => 'No Parking'}]

        temp[:sym_hash] = sym_hash.clone

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
        temp[:hash] = :drop

        full_hash[:bathrooms] = temp.clone

        temp[:tag] = '--bedrooms NUM'
        temp[:desc] = 'Filter out results with less than NUM bedrooms'
        temp[:range_low] = '0'
        temp[:range_high] = '8'
        temp[:var] = 'NUM'
        temp[:hash] = :drop

        full_hash[:bedrooms] = temp.clone

        temp[:tag] = '--min-price MIN_PRICE'
        temp[:desc] = 'Filter out results for less than MIN_PRICE'
        temp[:range_low] = nil
        temp[:range_high] = nil
        temp[:var] = 'MIN_PRICE'
        temp[:hash] = :fill

        full_hash[:min_price] = temp.clone

        temp[:tag] = '--max-price MAX_PRICE'
        temp[:desc] = 'Filter out results for more than MAX_PRICE'
        temp[:range_low] = nil
        temp[:range_high] = nil
        temp[:var] = 'MAX_PRICE'
        temp[:hash] = :fill

        full_hash[:max_price] = temp.clone

        temp[:tag] = '--min-sq-ft NUM'
        temp[:desc] = 'Filter out results with less than NUM square feet'
        temp[:range_low] = nil
        temp[:range_high] = nil
        temp[:var] = 'NUM'
        temp[:hash] = :fill

        full_hash[:minSqft] = temp.clone

        temp[:tag] = '--max-sq-ft NUM'
        temp[:desc] = 'Filter out results with more than NUM square feet'
        temp[:range_low] = nil
        temp[:range_high] = nil
        temp[:var] = 'NUM'
        temp[:hash] = :fill

        full_hash[:maxSqft] = temp.clone

        full_hash
    end # build_input_flags Method

    ### --Choose Hash-- ###
    #   Params: hash_id    - Symbol representing the hash that should be filled
    #           hash_key   - Key for the hash
    #           hash_value - Value for the hash
    #   Returns: <none>
    ###
    def choose_hash(hash_id, hash_key, hash_value)

        case hash_id
        when :checkbox
            @checkbox_fields[hash_key.to_sym] = hash_value
        when :fill
            @fill_fields[hash_key.to_sym] = hash_value
        when :drop
            @drop_fields[hash_key.to_sym] = hash_value
        when :mult
            temp = {:input => hash_value[:input],
                    :array => hash_value[:array]}
            @mult_fields[hash_key.to_sym] = temp.clone
        when :query
            @query[hash_key.to_sym] = hash_value
        else
            raise 'Unknown form field encountered.'
        end
    end # choose_hash Method

    ### --Parse Program Arguments-- ###
    #   Params: <none>
    #   Returns: Hash filled with search parameters.
    ###
    def parse_args
        bool_flags = build_bool_flags
        input_flags = build_input_flags

        OptionParser.new do |opt|

            opt.on('-h', '--help', 'Show this help message') { puts ''; puts opt; exit }

            bool_flags.each do |key, lower_hash|
                long = lower_hash[:long]
                desc = lower_hash[:desc]
                hash = lower_hash[:hash]
                array = lower_hash[:sym_hash]

                if lower_hash[:short]
                    short = lower_hash[:short]
                    opt.on("#{short}", "#{long}", "#{desc}") { |b|
                        choose_hash(hash, key, b)
                    }
                else
                    opt.on("#{long}", "#{desc}") { |b|

                        value = {}
                        value[:input] = b
                        value[:array] = array if array
                        choose_hash(hash, key, value.clone)
                    }

                end
            end

            input_flags.each do |key, lower_hash|
                tag = lower_hash[:tag]
                desc = lower_hash[:desc]
                var = lower_hash[:var]
                hash = lower_hash[:hash]

                opt.on("#{tag}", "#{desc}") { |o|
                    unless /\A[+-]?\d+\z/.match(o)
                        puts "#{var} must be a integer."
                        puts ''
                        puts opt
                        exit
                    end

                    o = Integer(o)

                    if (lower_hash[:range_low] && lower_hash[:range_high])
                        range_low = Integer(lower_hash[:range_low])
                        range_high = Integer(lower_hash[:range_high])
                            if (o < range_low || o > range_high)
                                puts "#{var} must be between #{range_low} and #{range_high} (inclusive)."
                                puts ''
                                puts opt
                                exit
                            end
                    elsif (lower_hash[:range_low])
                        range_low = Integer(lower_hash[:range_low])
                            if (o < range_low)
                                puts "#{var} must be less than #{range_low}."
                                puts ''
                                puts opt
                                exit
                            end
                    elsif (lower_hash[:range_high])
                        range_high = Integer(lower_hash[:range_high])
                            if (o > range_high)
                                puts "#{var} must be less than #{range_high}."
                                puts ''
                                puts opt
                                exit
                            end
                    end

                    choose_hash(hash, key, o)
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
                    puts ''
                    puts opt
                    exit
                end

                date = Date.new(year, month, day)
                current = Date.today
                sale_date = (date - current).to_i

                if sale_date < 0 || sale_date >= 28
                    puts 'Date outside valid range.'
                    puts ''
                    puts opt
                    exit
                end

                choose_hash(:fill, :sale_date, sale_date)
            }

        end.parse!
    end ## parse_args Method

    ### --Print Help Message for Interactive Session-- ###
    #   Params: type - The name of the flag that started interactive session.
    #           array - Array holding the symbol-string (key-value) pair
    #   Returns: <none>
    ###
    def isession_help(type, array)
        puts <<-EOS

    Type the number of each #{type} that should be included in the search, and press <Enter>.
    Type "0" when done.
EOS
        index = 1

        array.each do |element|
            element.each do |sym, string|
                puts "\t#{index} - #{string}"
            end
            index += 1
        end

        puts "\t0 - DONE"
    end # isession_help Method

end ## Scraper Class

##### OTHER METHODS #####
#   Current best-thinking:
#       - read_file


##### MAIN #####

c_list = Scraper.new()
c_list.fill_form.get_results.save_results

##### END #####
