require 'rubygems'
require 'mechanize'
require 'pry-byebug'
require 'csv'

scraper = Mechanize.new
scraper.history_added = Proc.new { sleep 0.5 }
BASE_URL = "https://listingservice.housing.queensu.ca/index.php/rental/rentalsearch/action/results_list/"
ADDRESS = "https://listingservice.housing.queensu.ca/index.php/rental/rentalsearch/action/results_list/pageID/1/"
results = []

scraper.get(ADDRESS) do |search_page|
    #search_form = search_page.form_with(:name => "searchFrm")
    search_form = search_page.form_with(:method => "GET")
    results_page = search_form.submit

    binding.pry
end

