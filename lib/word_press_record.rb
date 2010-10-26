require 'open-uri'

class WordPressRecord
  
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming
  
  
  @@wp_url = nil
  def self.wp_url(url)
    @@wp_url = url
  end
  
  
  @@wp_fields = [[:id, :integer], [:slug, :string], [:attachments, :array], [:images, :array]]
  attr_accessor :id, :slug, :attachments, :images
  
  def self.wp_field(*args)
    attr_accessor args[0]
    @@wp_fields.push args
  end
  
  
  @@wp_custom_fields = []  
  def self.wp_custom_field(*args)
    attr_accessor args[0]
    @@wp_custom_fields.push args
  end
  
  
  @@wp_after_load = nil
  def self.wp_after_load(symbol)
    @@wp_after_load = symbol
  end
  
  
  @@wp_post_type = :post
  def self.wp_post_type(post_type)
    @@wp_post_type = post_type
  end
  
  
  @@wp_queries = {}
  def self.wp_add_query(key, value)
    @@wp_queries[key] = value
  end
  
  def persisted?
    false
  end
  
  
  def initialize(attributes = {})
    wp_post = attributes[:wp_post]
    attributes.delete :wp_post
    
    attributes.each do |name, value|
      send("#{name}=", value)
    end
    
    load(wp_post) if self.slug or self.id or wp_post
  end
  
  
  def self.find(*args)
    
    # Find by id
    if args[0].is_a? Fixnum
      obj = new(:id => args[0])
      return obj.id ? obj : nil
    end
    
    # Find by slug
    if args[0].is_a? String
      obj = new(:slug => args[0])
      return obj.id ? obj : nil
    end
    
    # Find all
    if args[0] == :all
      return all(args[1])
    end
    
    nil
  end
  
  
  def self.all(params = nil)
    params ||= {}
    count = params[:count] || params[:limit] || 10
    page = (params[:page] || 0) + 1
    
    content = open("#{WP_URL}/?json=get_recent_posts&post_type=#{@@wp_post_type}&count=#{count}&page=#{page}#{WordPressRecord.wp_query_string}").read
    json = JSON.parse(content)
    
    return if json["status"] == 'error'
    return json["posts"].map{|post| new(:wp_post => post)}
  end
  
  
  private
  
  
  # Load an object from WordPress
  def load(post = nil)
    
    # Query WordPress, if necessary
    if post.nil?
      num_related = 3
      max_description_size = 160
    
      # Fetch the post
      url = "#{@@wp_url}/?json=get_post&post_type=#{@@wp_post_type}#{WordPressRecord.wp_query_string}"
      
      if self.id
        url += "&id=#{self.id}"
      elsif self.slug
        url += "&slug=#{self.slug}"
      else
        self.id = nil
        return
      end
            
      content = open(url).read
      json = JSON.parse(content)
      
      if json['status'] == 'error'
        self.id = nil
      else
        post = json['post']
      end
    end
    
    return if post.nil?
    
    # Populate the model's fields
    @@wp_fields.each do |field|
      name = field[0]
      if post["#{name}"]
        process_and_set_field(field, post["#{name}"])
      end
    end
    
    if post['custom_fields']
      @@wp_custom_fields.each do |field|
        name = field[0]
        if post['custom_fields']["#{name}"]
          process_and_set_field(field, post['custom_fields']["#{name}"])
        end
      end
    end
    
    # Special case for image attachments
    self.images = post['attachments'].map do |attachment|
      return nil unless attachment['images']
      {
        :files => attachment['images'],
        :caption => attachment['caption'],
        :title => attachment['title']
      }
    end.compact
    
    # Custom post processing
    self.send(@@wp_after_load, post) if @@wp_after_load
    
    self
  end
  
  
  def self.wp_query_string
    wp_query = ''
    
    @@wp_queries.each do |key, value|
      wp_query += "&#{CGI.escape(key.to_s)}=#{CGI.escape(value)}"
    end
    
    unless @@wp_custom_fields.empty?
      wp_query += "&custom_fields=#{@@wp_custom_fields.map{|f| f[0]}.join(',')}"
    end
    
    wp_query
  end
  
  
  def process_and_set_field(field, value)
    name = field[0]
    type = field[1]
    proc = field[2]
    
    if proc and proc.is_a? Proc
      value = proc.call(value)
    end
    
    if type == :string
      value = value.to_s
    elsif type == :text
      value = value.to_s
    elsif type == :integer
      value = value.to_i
    elsif type == :float
      value = value.to_f
    elsif type == :datetime
      value = Time.parse(value) rescue Time.at(value) rescue nil
    end
        
    send("#{name}=", value)
  end
  
end