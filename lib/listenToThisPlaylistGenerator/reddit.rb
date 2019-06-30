module ListenToThis
  class Reddit

    RESULTS_PER_PAGE = 50

    attr_reader :base_url
    attr_reader :after
    attr_reader :page
    attr_reader :posts
    attr_reader :range

    def initialize
      @range = ListenToThis::CONFIG['system']['range']

      reddit_base = ListenToThis::CONFIG['urls']['reddit_base']
      reddit_range_params = ListenToThis::CONFIG['urls'][@range]

      @base_url = "#{reddit_base}#{reddit_range_params}"
      @after = nil
      @page = 0
    end

    def next_page
      page = get_page

      begin
        @posts = get_posts(page)
        @after = get_after(page)
      rescue

      end
    end

    private

    def build_url(previous)
      previous ? @base_url + "&count=#{RESULTS_PER_PAGE}&after=#{previous}&limit=#{RESULTS_PER_PAGE}/" : @base_url
    end

    def get_posts(page)
      page["data"]["children"]
    end

    def get_after(page)
      page['data']['after']
    end

    def get_page
      JSON.parse(open(build_url(@after), 'User-Agent' => 'legitimateUser').read)
    end
  end
end
