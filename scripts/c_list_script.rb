require 'rubygems'
require 'mechanize'
require 'csv'
require 'pry-byebug'
require 'optparse'
require 'date'


##### TODO #####
#
#   - Extend to multiple sites
#       |-> Queen's Housing Service
#       |-> Kijiji
#       |-> Others...
#
#   - Parse multiple sites in same execution
#       |-> Dependency on above
#
#   - Print a status message on the terminal showing progress
#
#   - Investigate clearing of cookies, cache, other tracking mechanisms...
#
######################### ***RELEASE POINT*** #########################
#
#   - Add a flag that triggers logic specific to debugging
#
#   - Use hash/external file to map page elements to website
#       |-> Read file into arrays
#       |-> Introduce arguments to associated functions
#
#   - Use hash/external file to map form fields to website
#       |-> XML (use Nokogiri)
#
#   - Use hash/external file to map results data to website
#
#   - Extract all valuable data points from search results (get_results)
#       |-> Determine what information can be obtained directly from result
#           |--> Complete
#       |-> Clean-up data
#           |--> Complete
#       |-> Get contact information for posting
#           |--> Name (Complete)
#           |--> Phone Number (Complete)
#           |--> Email (Complete)
#       |-> Possible refactoring opportunity
#           |--> Refactor 'get_results' (Complete)
#           |--> Refactor 'save_results' (Complete)
#           |--> Make new class for results - Stretch
#           |--> Performance considerations - Stretch
#
#   - Optional: Distance optimization (e.g., limit to certain radius)
#   - Optional: Add other configurations to 'init'
#       |-> Pending result of investigation
#       |-> Clear cookies, cache, other tracking mechanisms...
#   - Optional: Save backup for use offline
#   - Optional: Mask robot-like behaviour of program (Impossible?)
#   - Optional: Get address information from Google (Impossible?)
#       |-> Navigate to map page 
#       |-> Calculate distance

##### GLOBAL VARIABLES #####

# Hard-coded default address in case none provided
ADDRESS = 'http://kingston.craigslist.ca/search/apa'

##### SCRAPER CLASS #####

class Scraper

    def initialize()
        @scraper = init()
        @search_form = nil
        @search_results = []
        @query= {}
        @checkbox_fields = {}
        @fill_fields = {}
        @drop_fields = {}
        @mult_fields = {}
    end ## initialize Method


    public

    ### --Retrieve and fill form-- ###
    #   Params: <none>
    #   Returns: Completed search form
    ###
    def fill_form
        # Validate argument variables
        raise "Mechanize object not initialized properly." unless @scraper.respond_to?(:get)

        # Parse arguments
        parse_args

        # Begin scraping
        search_page = @scraper.get(@website.clone)

        # Work with the form. Used block to wrap all form fields in separate scope.
        form = search_page.form_with( :id => 'searchform' ) do |search|

            # Search query related
            search.query = @query[:query] if @query[:query]
            search.checkbox_with( :name => 'srchType' ).check if (@query[:query] && @query[:srch_type])

            if @query[:output_file]
                puts <<-EOS

    Please enter the name of each file you would like to be a part of the
    output, separated by a comma. When you are done please press <Enter>.

    For example, if you want to output a .csv file and a .txt file, type
    the following:

        file_1.csv, file_2.txt

EOS

                print "    <files>: "
                input = gets.chomp!
                @output_files = input.split(/,? /)
            end

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
                        # Should only be one key-value pair
                        inner_hash.each do |symbol, string|
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
        @search_results = []

        # Add a description of what each element contains.
        @search_results << [
            'Name of entry',
            'URL of the entry',
            'Listing price',
            'Location of building',
            'Date entry was posted',
            'Number of bedrooms',
            'Size of the building (in square feet)',
            'Landlord\'s name',
            'Landlord\'s number',
            'Landlord\'s email'
        ]

        # Parse the results
        raw_results.each do |result|

            # Elements to split into:
            #   - Posting information (Name, URL, Date added)
            #   - House details (Price, Location, Bed, Bath, Size)
            #   - Contact info (Name, Number, Email)

            posting_details = extract_posting_details(result)
            name = posting_details[0]
            url = posting_details[1]
            date = posting_details[2]

            house_details = extract_house_details(result)
            price = house_details[0]
            location = house_details[1]
            bed = house_details[2]
            size = house_details[3]
            
            contact_details = extract_contact_details(result_page.link_with(:text => name).click)
            contact_name = contact_details[0]
            contact_number = contact_details[1]
            email = contact_details[2]

            # Save the results
            @search_results << [name, url, price, location, date, bed, size, contact_name, contact_number, email]

            break   # Debugging only
        end

        self
    end ## get_results Method

    ### --Save files-- ###
    #   Params: *file - Any number of file names to save results to
    #           results - Array containing results to be saved
    #   Returns: <none>
    ###
    def save_results

        unless @output_files
            puts 'No output file provided.'
            @output_files = []
            @output_files << 'output.txt'
        end

        @output_files.each do |file|
            file = File.expand_path(__FILE__).gsub!('scripts/' << __FILE__, 'test_output/' << file)
            if /.*\.csv\z/.match(file)
                puts "Saving to CSV file:\n\t#{file}"
                CSV.open(file, "w+") do |csv_file|
                    @search_results.each do |row|
                        csv_file << row
                    end
                end
            elsif /.*\.txt\z/.match(file)
                save_txt(file)
            else
                puts "Unrecognized file format."

                if file =~ /\A(.*)\.(.*?)\z/
                    file = "#{$1}.txt"
                elsif file =~ /\A([^\.]+)\z/
                    file = "#{$1}.txt"
                end

                save_txt(file)
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
        scraper.history_added = Proc.new { sleep 0.75 }

        scraper
    end ## init Method

    ### --Build Hash for Boolean Flag Arguments-- ###
    #   Params: <none>
    #   Returns: Hash filled with syntax details for boolean flags.
    ###
    def build_bool_flags
        full_hash = {}
        temp = {}

        temp = {:short => '-c',
                :long => '--allow-cat',
                :desc => 'Filter out results that do NOT allow cats',
                :hash => :checkbox,
                :sym_hash => nil
        }

        full_hash[:pets_cat] = temp.clone

        temp = {:short => '-d',
                :long => '--allow-dog',
                :desc => 'Filter out results that do NOT allow dogs',
                :hash => :checkbox,
                :sym_hash => nil
        }

        full_hash[:pets_dog] = temp.clone

        temp = {:short => '-f',
                :long => '--furnished',
                :desc => 'Filter out results that are NOT furnished',
                :hash => :checkbox,
                :sym_hash => nil
        }

        full_hash[:is_furnished] = temp.clone

        temp = {:short => '-o',
                :long => '--output',
                :desc => 'Opens an interactive sesstion to specify output file',
                :hash => :query,
                :sym_hash => nil
        }

        full_hash[:output_file] = temp.clone

        temp = {:short => '-p',
                :long => '--has-pic',
                :desc => 'Only show results with a picture',
                :hash => :checkbox,
                :sym_hash => nil
        }

        full_hash[:hasPic] = temp.clone

        temp = {:short => '-q',
                :long => '--query QUERY',
                :desc => 'Search for results that include QUERY',
                :hash => :query,
                :sym_hash => nil
        }

        full_hash[:query] = temp.clone

        temp = {:short => '-s',
                :long => '--no-smoking',
                :desc => 'Filter out results that allow smoking',
                :hash => :checkbox,
                :sym_hash => nil
        }

        full_hash[:no_smoking] = temp.clone

        temp = {:short => '-t',
                :long => '--title-only',
                :desc => 'Search for query in title only',
                :hash => :query,
                :sym_hash => nil
        }

        full_hash[:srchType] = temp.clone

        temp = {:short => '-w',
                :long => '--wheelchair',
                :desc => 'Filter out results that are NOT wheelchair accessible',
                :hash => :checkbox,
                :sym_hash => nil
        }

        full_hash[:wheelchaccess] = temp.clone

        temp = {:short => nil,
                :long => '--nearby',
                :desc => 'Only show nearby results',
                :hash => :checkbox,
                :sym_hash => nil
        }

        full_hash[:searchNearby] = temp.clone

        temp = {:short => nil,
                :long => '--posted-today',
                :desc => 'Only show results posted today',
                :hash => :checkbox,
                :sym_hash => nil
        }

        full_hash[:postedToday] = temp.clone

        sym_hash = [{:apartment_1 => 'Apartment'},
                    {:condo_2 => 'Condo'},
                    {'cottage/cabin_3'.to_sym => 'Cottage/Cabin'},
                    {:duplex_4 => 'Duplex'},
                    {:flat_5 => 'Flat'},
                    {:house_6 => 'House'},
                    {'in-law_7'.to_sym => 'In-Law'},
                    {:loft_8 => 'Loft'},
                    {:townhouse_9 => 'Townhouse'},
                    {:manufactured_10 => 'Manufactured'},
                    {:assisted_living_11 => 'Assisted Living'},
                    {:land_12 => 'Land'}
        ]

        temp = {:short => nil,
                :long => '--housing-type',
                :desc => 'Opens an interactive session to filter search results by housing type',
                :hash => :mult,
                :sym_hash => sym_hash.clone
        }

        full_hash[:housing_type] = temp.clone

        sym_hash = [{'w/d_in_unit_1'.to_sym => 'W/D in Unit'},
                    {:laundry_in_bldg_2 => 'Laundry in Building'},
                    {:laundry_on_site_3 => 'Laundry on Site'},
                    {'w/d_hookups_4'.to_sym => 'W/D Hookups'},
                    {:no_laundry_on_site_5 => 'No Laundry on Site'}
        ]

        temp = {:short => nil,
                :long => '--laundry',
                :desc => 'Opens an interactive session to filter search results by laundry options',
                :hash => :mult,
                :sym_hash => sym_hash.clone
        }

        full_hash[:laundry] = temp.clone

        sym_hash = [{:carport_1 => 'Carport'},
                    {:attached_garage_2 => 'Attached Garage'},
                    {:detached_garage_3 => 'Detached_Garage'},
                    {'off-street_parking_4'.to_sym => 'Off-Street Parking'},
                    {:street_parking_5 => 'Street Parking'},
                    {:valet_parking_6 => 'Valet Parking'},
                    {:no_parking_7 => 'No Parking'}
        ]

        temp = {:short => nil,
                :long => '--parking',
                :desc => 'Opens an interactive session to filter search results by parking options',
                :hash => :mult,
                :sym_hash => sym_hash.clone
        }

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

        temp = {:tag => '--bathrooms NUM',
                :desc => 'Filter out results with less than NUM bathrooms',
                :range_low => '0',
                :range_high => '8',
                :var => 'NUM',
                :hash => :drop
        }

        full_hash[:bathrooms] = temp.clone

        temp = {:tag => '--bedrooms NUM',
                :desc => 'Filter out results with less than NUM bedrooms',
                :range_low => '0',
                :range_high => '8',
                :var => 'NUM',
                :hash => :drop
        }

        full_hash[:bedrooms] = temp.clone

        temp = {:tag => '--min-price MIN_PRICE',
                :desc => 'Filter out results for less than MIN_PRICE',
                :range_low => nil,
                :range_high => nil,
                :var => 'MIN_PRICE',
                :hash => :fill
        }

        full_hash[:min_price] = temp.clone

        temp = {:tag => '--max-price MAX_PRICE',
                :desc => 'Filter out results for more than MAX_PRICE',
                :range_low => nil,
                :range_high => nil,
                :var => 'MAX_PRICE',
                :hash => :fill
        }

        full_hash[:max_price] = temp.clone

        temp = {:tag => '--min-sq-ft NUM',
                :desc => 'Filter out results with less than NUM square feet',
                :range_low => nil,
                :range_high => nil,
                :var => 'NUM',
                :hash => :fill
        }

        full_hash[:minSqft] = temp.clone

        temp = {:tag => '--max-sq-ft NUM',
                :desc => 'Filter out results with more than NUM square feet',
                :range_low => nil,
                :range_high => nil,
                :var => 'NUM',
                :hash => :fill
        }

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
                    :array => hash_value[:array]
            }
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

            # Customized usage message
            opt.banner = "Usage: c_list_script.rb [options] [<website>]\n\n"

            opt.on('-h', '--help', 'Show this help message') {
                puts ''
                puts opt
                exit
            }

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

            # Special options
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

        ARGV.each do |arg|
            if arg =~ /\A#{URI::regexp}\z/
                @website = arg
            end
        end

        unless @website
            puts 'URL invalid or not provided. Reverting to default address'
            @website = ADDRESS
        end
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

    ### --Extract Details About the Posting-- ###
    #   Params: result - Result entry that needs to be parsed
    #   Returns: Array holding the entry name, URL, and the date it was added.
    ###
    def extract_posting_details(result)

        # Attributes that need to be cleaned up after parsing
        link = result.css('a')[1]
        datetime = result.css('time')[0]

        # To be inconvenient, the name is made a link to the page, so
        #   it needs to be parsed. Also, link doesn't contain base address
        #   so this needs to be prepended.
        name = link.text.strip
        url = "http://kingston.craigslist.ca" + link.attributes["href"].value

        # Date seems like a repetition of data on their part, but it's nicely
        #   formatted already so I won't complain.
        date = datetime.text.strip

        details = [name, url, date]

        details
    end # extract_posting_details Method

    ### --Initialize Mechanize-- ###
    #   Params: result - Result entry that needs to be parsed
    #   Returns: Array holding the price, location, number of bedrooms, and size of the
    #       house.
    ###
    def extract_house_details(result)

        # Price is in a nice easy location to access
        price = result.search('span.price').text.strip

        # Very strange name for element. Also, this location isn't always
        #   an address, so maybe we can look for another way to access it?
        #       -> Brief investigation into parsing from Google maps page was
        #           fruitless
        location = result.search('span.pnr').text.strip

        # Strip away the 'pic' and 'map' links that definitely make sense
        #   to include in this intuitively named 'pnr' element...
        if location =~ /\(([^\)]+)\)/
            location = $1
        end

        # Another odd name, but contains the number of bedrooms and square
        #   footage of the place...
        housing = result.search('span.housing').text.strip

        # ...but number of bedrooms still needs to be parsed out...
        if housing =~ /(\d+)br/
            bed = $1
        end

        # ...and size too, which is labelled quite awkwardly.
        if housing =~ /(\d+)ft2/
            size = $1 << 'sq. ft'
        end

        # NOTE: It looks like the entry page may also have this information.
        #   Maybe it can be parsed from there instead.

        details = [price, location, bed, size]

        details

        # NOTE: It looks like the entry page may also have this information.
        #   Maybe it can be parsed from there instead.
    end # extract_house_details Method


    ### --Initialize Mechanize-- ###
    #   Params: result_entry_page - The page of the entry.
    #   Returns: Array holding the contact's name, number, and email.
    ###
    def extract_contact_details(result_entry_page)

        # Ok, we have to dive kinda deep here to get the contact info.

        # These are used for testing because using the above takes the most recent post.
        #result_entry_page = result_page.link_with(:text => '4-Bedroom Unit').click    # Email only
        #result_entry_page = result_page.link_with(:text => '1 bedroom apartment with grade level entry,').click   # Ayanda, and number
        #result_entry_page = result_page.link_with(:text => 'Awesome loft in heritage building').click    # Just number

        # We want the 'reply' link, which HOPEFULLY holds all the
        #   contact information of the posting.
        reply_page = result_entry_page.link_with(:text => 'reply').click

        # All contact information should be embedded in the 'reply_options'
        #   element
        options_element = reply_page.search('div.reply_options')

        contact_name = '<name_not_provided>'
        contact_number = '<number_not_provided>'

        index = 0

        # Need to make sure that the contact name and number are actually provided.
        # Should check all elements, for robustness.
        options_element.css('b').each do |label|

            # Logic below associates a label with the data that immediately follows it.
            #   If it's the data we want, extract it. Otherwise, skip to next label.
            if label.text.strip === 'contact name:'
                contact_name = options_element.css('ul')[index].text.strip
            elsif label.text.strip === 'text'
                contact_number = options_element.css('ul')[index].text.strip
            else
                index += 1
                next
            end

            index += 1
        end

        # Clear previous value of email.
        email = nil

        # Email SHOULD always be there, so it's pretty easy to get.
        email = reply_page.search('div.anonemail').text.strip

        # Missing email may be an indication that we hit at Captcha...
        puts "Something may have gone wrong..." unless email

        details = [contact_name, contact_number, email]

        details
    end # extract_contact_details Method

    ### --Save Results to Text File-- ###
    #   Params: file - File that it should be saved.
    #   Returns: <none>
    ###
    def save_txt(file)
        puts "Saving to text file:\n\t#{file}"
        File.open(file, "w+") do |txt_file|
            @search_results.each do |row|
                name = row[0]
                url = row[1]
                price = row[2]
                location = row[3]
                date = row[4]
                bed = row[5]
                size = row[6]
                contact = row[7]
                number = row[8]
                email = row[9]

                txt_file << "Name: #{name}"
                txt_file << "\n\t"

                txt_file << "URL: #{url}"
                txt_file << "\n\t"

                txt_file << "Price: #{price}"
                txt_file << "\n\t"

                txt_file << "Location: #{location}"
                txt_file << "\n\t"

                txt_file << "Date Added: #{date}"
                txt_file << "\n\t"

                txt_file << "Bedrooms: #{bed}"
                txt_file << "\n\t"

                txt_file << "Size: #{size}"
                txt_file << "\n\t"

                txt_file << "Contact name: #{contact}"
                txt_file << "\n\t"

                txt_file << "Contact number: #{number}"
                txt_file << "\n\t"

                txt_file << "Email: #{email}"
                txt_file << "\n\n"
            end
        end
    end # save_txt Method

end ## Scraper Class

##### OTHER METHODS #####
#   Current best-thinking:
#       - read_file


##### MAIN #####

c_list = Scraper.new()
c_list.fill_form.get_results.save_results

##### END #####
