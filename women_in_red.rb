require 'net/http'
require_relative './wiki_api'
require 'pp'
require 'date'
require 'csv'

puts 'ohai'

pages_to_check = ['User:AlexNewArtBot/WomensHistorySearchResult',
                  'User:AlexNewArtBot/WomenartistsSearchResult',
                  'User:AlexNewArtBot/WomenWritersSearchResult',
                  'User:AlexNewArtBot/WomenScientistsSearchResult',
                  'User:AlexNewArtBot/OperaSearchResult']

def article_links_query(revid)
  query = { prop: 'links',
            revids: revid,
            plnamespace: 0,
            pllimit: 500 }
  query
end

def revisions_query(page_title)
  query = { prop: 'revisions',
            titles: page_title,
            rvlimit: 60 }
  query
end

def recent_revision_ids(page_title)
  query = revisions_query(page_title)
  response = Wiki.query query
  revids = []
  response.data['pages'].values[0]['revisions'].each do |rev|
    revids << rev['revid']
  end
  revids
end

def article_links(revid)
  linked_titles = []
  query = article_links_query(revid)
  continue = true
  i = 0
  until continue.nil?
    response = Wiki.query query
    pp revid
    pp i += 1
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

revids_to_check = []

pages_to_check.each do |page_title|
  revids_to_check += recent_revision_ids(page_title)
end

articles_linked = []

revids_to_check.each do |revid|
  articles_linked += article_links(revid)
  pp articles_linked.size
end

pp articles_linked.size

articles_linked = articles_linked.uniq

pp 'ohai'
pp articles_linked.size

articles_linked = articles_linked.map do |title|
  { title => creation_date(title) }
end

articles_by_month = articles_linked.group_by do |title_and_date|
  title_and_date.values[0][0..6]
end

articles_by_month.each do |month, articles_for_month|
  articles_for_month.sort_by! { |x| x.values[0] }.reverse
end

articles_by_month.each do |month, articles_for_month|
  CSV.open("/var/www/html/#{month}.csv", 'wb') do |csv|
    articles_for_month.each do |article|
      title = article.keys[0]
      date = article.values[0]
      csv << [title, date]
    end
  end
end
