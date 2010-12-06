require 'open-uri'

class WordPressRecord
  
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming
  
  class_attribute :_wp_fields, :_wp_url, :_wp_headers, :_wp_custom_fields, :_wp_after_load, :_wp_post_type, :_wp_queries
  
  self._wp_fields = [
    [:id, :integer],
    [:slug, :string],
    [:attachments, :array],
    [:images, :array],
    [:categories, :array],
    [:tags, :array]
  ]
  
  self._wp_fields.each { |f| attr_accessor f[0] }
  
  def self.wp_field(*args)
    attr_accessor args[0]
    self._wp_fields = self._wp_fields.clone
    self._wp_fields.push args
  end
  
  
  self._wp_url = nil
  def self.wp_url(url)
    self._wp_url = url
  end
  
  
  self._wp_headers = {}
  def self.wp_headers(headers)
    self._wp_headers = headers
  end
  
  
  self._wp_custom_fields = []  
  def self.wp_custom_field(*args)
    attr_accessor args[0]
    self._wp_custom_fields = self._wp_custom_fields.clone
    self._wp_custom_fields.push args
  end
  
  
  self._wp_after_load = nil
  def self.wp_after_load(symbol)
    self._wp_after_load = symbol
  end
  
  
  self._wp_post_type = :post
  def self.wp_post_type(post_type)
    self._wp_post_type = post_type
  end
  
  
  self._wp_queries = {}
  def self.wp_add_query(key, value)
    self._wp_queries = self._wp_queries.clone
    self._wp_queries[key] = value
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
    params[:results_metadata] ||= {}
    
    count = params[:count] || params[:limit] || 10
    page = (params[:page] || 0) + 1
    
    category = nil
    search = nil
    tags = nil
    
    method = 'queries.general'
    
    if params[:category]
      category = CGI.escape(params[:category])
    end
    
    if params[:search]
      search = CGI.escape(params[:search].strip)
    end
    
    if params[:tagged]
      tags = CGI.escape(params[:tagged].to_s.gsub(/\s*,\s*/, ',').gsub(/\s+/, ' '))
    end
    
    url = "#{self._wp_url}/?json=#{method}&post_type=#{self._wp_post_type}&count=#{count}&page=#{page}#{wp_query_string}"
    url += "&search=#{search}" if search
    url += "&category=#{category}" if category
    url += "&tags=#{tags}" if tags
    
    content = open(url, self._wp_headers).read
    json = JSON.parse(content)
    
    params[:results_metadata][:url] = url
    params[:results_metadata][:count] = json['count']
    params[:results_metadata][:count_total] = json['count_total']
    params[:results_metadata][:pages] = json['pages']
    
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
      url = "#{self._wp_url}/?json=get_post&post_type=#{self._wp_post_type}#{self.class.wp_query_string}"
      
      if self.id
        url += "&id=#{self.id}"
      elsif self.slug
        url += "&slug=#{self.slug}"
      else
        self.id = nil
        return
      end
      
      content = open(url, self._wp_headers).read
      json = JSON.parse(content)
      
      if json['status'] == 'error'
        self.id = nil
      else
        post = json['post']
      end
    end
    
    return if post.nil?
    
    # Populate the model's fields
    self._wp_fields.each do |field|
      name = field[0]
      if post["#{name}"]
        process_and_set_field(field, post["#{name}"])
      end
    end
    
    if post['custom_fields']
      self._wp_custom_fields.each do |field|
        name = field[0]
        if post['custom_fields']["#{name}"]
          process_and_set_field(field, post['custom_fields']["#{name}"][0])
        end
      end
    end
    
    # Special case for attachments / images
    self.images = self.attachments.map do |attachment|
      return nil unless attachment['images']
      {
        "files" => attachment['images'],
        "caption" => attachment['caption'],
        "title" => attachment['title']
      }
    end.compact
    
    # Custom post processing
    self.send(self._wp_after_load, post) if self._wp_after_load
    
    self
  end
  
  
  def self.wp_query_string
    wp_query = ''
    
    self._wp_queries.each do |key, value|
      wp_query += "&#{CGI.escape(key.to_s)}=#{CGI.escape(value)}"
    end
    
    unless self._wp_custom_fields.empty?
      wp_query += "&custom_fields=#{self._wp_custom_fields.map{|f| f[0]}.join(',')}"
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
    elsif type == :array
      value = value.to_a
    elsif type == :hash
      value ||= {}
    end
    
    send("#{name}=", value)
  end
  
end