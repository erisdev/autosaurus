require 'mechanize'

class Autosaurus
  CACHE_FILE = File.join ENV['HOME'], '.autosaurus.yml'
  
  def initialize
    @agent = Mechanize.new
    @cache = File.exist?(CACHE_FILE) ? YAML.load_file(CACHE_FILE) : Hash[]
  end
  
  def run *args
    # TODO allow ignoring cache
    # TODO support for related words as well
    puts transform(args).join ' '
  ensure
    File.open(CACHE_FILE, 'w') { |io| YAML.dump @cache, io }
  end
  
  def transform words
    words.map do |word|
      synonyms = fetch_synonyms word
      synonyms[rand synonyms.length]
    end
  end
  
  def fetch_synonyms word
    synonyms = @cache[word.downcase] || []
    return synonyms unless synonyms.empty?
    
    page = @agent.get "http://www.merriam-webster.com/thesaurus/#{word}"
    page.search('//*[text()="Synonyms"]').each do |node|
      text = node.search('./following-sibling::node()/descendant-or-self::text()').text
      synonyms |= text.split(/,\s*/).map! do |word|
        word.gsub!(/\[ [^\]]* \]/x, '')
        word.gsub!(/^\s+|\s+$/, '')
        word
      end.sort
    end
    
    if synonyms.empty?
      synonyms << word
    else
      synonyms.delete word
    end
    
    @cache[word.downcase] = synonyms
    synonyms
  end

end

Autosaurus.new.run(*ARGV)
