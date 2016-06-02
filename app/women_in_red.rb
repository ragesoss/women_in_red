require 'net/http'
require './wiki_api'
require 'pp'
require 'date'
require 'csv'

puts 'ohai'

pages_to_check = ["Wikipedia:WikiProject Women's history/New articles",
                  'User:AlexNewArtBot/WomenartistsSearchResult',
                  'User:AlexNewArtBot/WomenWritersSearchResult',
                  'User:AlexNewArtBot/WomenScientistsSearchResult',
                  'User:AlexNewArtBot/OperaSearchResult']

def article_links_query(page_title)
  query = { prop: 'links',
            titles: page_title,
            plnamespace: 0,
            pllimit: 500 }
  query
end

def article_links(page_title)
  linked_titles = []
  query = article_links_query(page_title)
  continue = true
  until continue.nil?
    response = Wiki.query query
    results = response.data['pages'].values[0]['links']
    results.each do |page|
      linked_titles << page['title']
    end
    continue = response['continue']
    query[:plcontinue] = continue['plcontinue'] if continue
  end
  linked_titles
end

def creation_date(title)
  pp title
  response = Wiki.query prop: 'revisions',
                        titles: title,
                        rvdir: 'newer',
                        rvlimit: 1
  return 'missing' if response.data['pages'].values[0]['missing']
  Date.parse(response.data['pages'].values[0]['revisions'][0]['timestamp']).to_s
end

articles_linked = []

pages_to_check.each do |page|
  articles_linked += article_links(page)
end

articles_linked = articles_linked.uniq

articles_linked = articles_linked.map do |title|
  { title => creation_date(title) }
end

pp articles_linked

articles_by_month = articles_linked.group_by do |title_and_date|
  puts title_and_date.keys[0]
  puts title_and_date.values[0]
  title_and_date.values[0][0..6]
end

articles_by_month.each do |month, articles_for_month|
  pp articles_for_month
  articles_for_month.sort_by! { |x| x.values[0] }.reverse
end

articles_by_month.each do |month, articles_for_month|
  CSV.open("#{Rails.root}/public/#{month}.csv", 'wb') do |csv|
    articles_for_month.each do |article|
      title = article.keys[0]
      date = article.values[0]
      csv << [title, date]
    end
  end
end
