require 'httparty'
require 'nokogiri'
require 'json'
require_relative 'json_parser'
require_relative 'api'

module InstagramCrawler
  class Crawl
    extend InstagramCrawler::JSONParser

    DEFAULT_URL_PREFIX = 'https://www.instagram.com/'
    TAG_URL_PREFIX = 'explore/tags/'
    LINK_URL_PREFIX = 'http://instagr.am/p/'

    @@hashtag = ''
    @@limit = 12
    @@is_user = false

    def self.get_info_hash(hashtag:, limit:, is_user: @@is_user)
      self.hashtag = hashtag
      self.limit = limit
      self.is_user = is_user

      url = set_url
      parse_page = get_and_parse(url)
      json = get_parsed_json(parse_page)
      data = json.any? ? get_json_nodes(json) : json
      nodes = get_data_nodes(data)

      mapped_data = nodes.map do |post|
        get_hash_for_post(post)
      end
      mapped_data
    end

    def self.tag_api(hashtag:, limit: @@limit)
      Api.new(hashtag: hashtag, limit: limit)
    end

    class << self
      [:hashtag, :limit, :is_user].each do |method|
        define_method method do
          eval "@@#{method.to_s}"
        end

        define_method "#{method}=" do |value|
          value = if value.is_a? String
                    "'#{value}'"
                  else
                    value
                  end
          eval "@@#{method.to_s}=#{value}"
        end
      end

      def get_json_nodes(json)
        page = is_user ? 'ProfilePage' : 'TagPage'
        type = is_user ? 'user' : 'hashtag'

        json['entry_data'][page]
          .first['graphql'][type]['edge_hashtag_to_media']['edges']
          .first(limit)
      end

      def get_data_nodes(edges)
        nodes = Array.new
        edges.each do |edge|
          nodes << edge['node']
        end
        return nodes
      end

      def get_hash_for_post(post)
        {
          id: post['id'],
          images: {
            thumbnail: { url: post['thumbnail_src'] },
            standard_resolution: { url: post['display_url'] }
          },
          code: post['shortcode'], caption: post['edge_media_to_caption'],
          created_time: post['taken_at_timestamp'], link: LINK_URL_PREFIX + post['shortcode'] + '/',
          likes: post['edge_liked_by'], comments: post['edge_media_to_comment']
        }
      end

      def get_and_parse(url)
        Nokogiri::HTML HTTParty.get(url)
      end

      def set_url
        prefix_url = if is_user
                       DEFAULT_URL_PREFIX
                     else
                       DEFAULT_URL_PREFIX + TAG_URL_PREFIX
                     end
        prefix_url + hashtag
      end
    end
  end
end
