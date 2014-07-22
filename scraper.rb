
# Fetch voting information from the KansanMuisti API

require 'json'
require 'scraperwiki'
require 'open-uri'

@API = "http://dev.kansanmuisti.fi/api/v1"

def api_fetch (str)
  json = JSON.parse(open("#{@API}#{str}").read)
end

def plenary_sessions_with_votes
  api_fetch("/plenary_session/")['objects'].reject { |s| s['plenary_votes'].count.zero? }
end

def plenary_session_item (uri)
  id = uri[/plenary_session_item\/(\d+)/,1]
  api_fetch("/plenary_session_item/#{id}/")
end

def rollcall (pvid)
  api_fetch("/vote/?limit=200&plenary_vote=#{pvid}")['objects']
end

def plenary_vote (uri)
  id = uri[/plenary_vote\/(\d+)/,1]
  pv = api_fetch("/plenary_vote/#{id}")
  pv['session_item'] = plenary_session_item(pv['session_item'])
  pv['roll_call'] = rollcall(id)
  return pv
end

def vote_option (str)
  return 'yes' if str == 'Y'
  return 'no' if str == 'N'
  return 'absent' if str == 'A'
  return 'abstain' if str == 'E'
  raise "Unknown vote option: #{str}"
end

plenary_sessions_with_votes.each do |session|
  session['plenary_votes'].map { |uri| plenary_vote(uri) }.each do |plenary_vote|
  
    data = {
      'voteid' => plenary_vote['id'],
      'time' => plenary_vote['time'],
      'session_id' => session['origin_id'],
      'text' => plenary_vote['setting'],
      'context' => plenary_vote['subject'],
      'classification' => "#{plenary_vote['session_item']['processing_stage']} | #{plenary_vote['session_item']['type']}",
    }
    puts "Vote #{data['voteid']}"

    ScraperWiki.save_sqlite(['voteid'], data)

    rcvs = plenary_vote['roll_call'].map { |pv|
      {
        'voteid' => plenary_vote['id'],
        'voter' => pv['member'][/member\/(\d+)/,1],
        'option' => vote_option(pv['vote']),
        'grouping' => pv['party'],
      }
    }
    ScraperWiki.save_sqlite(['voteid','voter'], rcvs, 'vote')
  end
end


