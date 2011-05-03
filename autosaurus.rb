require 'mechanize'

class Autosaurus
  CACHE_FILE = File.join ENV['HOME'], '.autosaurus.yml'
  WORD_URI   = 'http://www.merriam-webster.com/thesaurus/%s'
  
  def initialize
    @agent = Mechanize.new
    @cache = File.exist?(CACHE_FILE) ? YAML.load_file(CACHE_FILE) : Hash[]
  end
  
  def run *args
    # TODO allow ignoring cache
    # TODO support for related words as well
    # TODO decline and conjugate to find synonyms for plurals, past tenses &c.
    puts args.map { |text| transform text }
  ensure
    File.open(CACHE_FILE, 'w') { |io| YAML.dump @cache, io }
  end
  
  def transform text
    text.gsub /\w+/ do |word|
      if word.match /^(?:[[:upper:]][[:lower:]]+){2,}$/
        word.split(/(?<=[[:lower:]])(?=[[:upper:]])/).
          map { |subword| match_case transform(subword), subword }.
          join('')
      else
        match_case synonym(word), word
      end
    end
  end
  
  def match_case to, from
    case from
    when /^[[:upper:]]+$/            then to.upcase
    when /^[[:lower:]]+$/            then to.downcase
    when /^[[:upper:]][[:lower:]]+$/ then to.split(/\s+/).map(&:capitalize).join(' ')
    else to
    end
  end
  
  def synonym word
    synonyms = fetch_synonyms word.downcase
    synonyms[rand synonyms.length]
  end
  
  def fetch_synonyms word
    synonyms = @cache[word.downcase] || []
    return synonyms unless synonyms.empty?
    
    page = @agent.get WORD_URI % word
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
