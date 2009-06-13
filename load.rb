require 'rubygems'
require 'net/http'
require 'datamapper'

DataMapper.setup(:default, "mysql://root@localhost/wow2")
DataMapper.auto_upgrade!

class Card
  include DataMapper::Resource
  property :id, Integer, :key => true
  property :name, String
  property :cardtype, String
  property :fraction, String
  property :supertype, String
  property :subtype, String
  property :race, String
  property :klass, String
  property :talent, String
  property :tags, String, :size => 100
  property :professions, String, :size => 100
  property :atktype, String
  property :restrictions, String
  property :allowedclass, String, :size => 100
  property :allowedrace, String, :size => 100
  property :allowedprofession, String, :size => 100
  property :allowedtalent, String, :size => 100
  property :rules, Text
  property :cost, String
  property :strikecost, String
  property :atk, String
  property :health, String
  property :def, String
  property :flavor, Text
  property :number, String
  property :set, String
  property :rarity, String
  property :artist, String, :size => 100
  property :image, String, :size => 100
end

class Page
  attr_accessor :html
  def initialize(url)
    self.html = Net::HTTP.get(URI.parse(url))
  end
end

class ListPage < Page
  def initialize
    puts "ładuję listę kart, może to potrwać kilka minut"
    super('http://wowtcgdb.com/type-all.aspx')
    puts "załadowałem listę kart"
  end
  
  def ids
    html.scan(/carddetail.aspx\?id=(\d+)/).map do |match|
      id = match[0]
    end
  end
  
  def load
    puts "ściągam karty"
    ids.each {|id| CardPage.new(id).load unless Card.get(id)}
  end
end

class CardPage < Page
  def initialize(id)
    @id = id
    super('http://wowtcgdb.com/carddetail.aspx?id=' + id.to_s)
  end
  
  def to_s
    html
  end
  
  def load
    return if name and name.downcase == "deleted"
    card = Card.new
    Card.properties.map { |p| p.name.to_s }.each do |p|
      if val = send(p)
        card.send(p + '=', val)
      end
    end
    if card.save
      puts "+ " + card.name.to_s
    else
      puts "! " + card.id.to_s + " " + card.name.to_s
      card.errors.keys do |param|
        puts "\t" + param.to_s + ":"
        card.errors[key].each do |e|
          puts "\t\t" + e.to_s
        end
      end
    end
  end
  
  def match(regexp);  m = html.match(regexp) and m[1]; end
  def span(id);       /<span id="#{id}">(.+)<\/span>/; end
  def field(id);      /<span id="ctl00_body_FormView1_#{id}Label">(.+)<\/span>/; end
  
  def id;             @id; end
  def name;           @name ||= match(span('ctl00_body_FormView1_Label1')); end
  def fraction;       match(field('faction')); end
  def klass;          match(field('class')); end
  def cardtype;       match(field('type')); end
  def tags;           match(field('keywords')); end
  def set;            match(span('ctl00_body_FormView1_Label4')); end
  def artist;         match(/<a id="ctl00_body_FormView1_HyperLink1" .+>(.+)<\/a>/); end
  def image;          m = html.match(/src="images\/medium\/(.+)\.jpg/) and "http://wowtcgdb.com/images/medium/#{m[1]}.jpg"; end
  def method_missing(method, *args); match(field(method.to_s)); end
end

ListPage.new.load