class Project < ApplicationRecord
  belongs_to :user

  scope :ordered, -> { order(position: :asc) }

  def sync(data = nil)
    sync_repository(data)
    sync_homepage

    save!
  end

  def sync_repository(data = nil)
    return false unless self.repository.present?

    data ||= client.repository(self.repository)

    self.title = data.name.titleize
    self.homepage = data.homepage
    self.repository = data.full_name
    self.description = data.description
    self.language = data.language
  end

  def sync_homepage
    return false unless self.homepage.present?

    begin
      page = MetaInspector.new(self.homepage)
      return false unless page.response.status == 200

      self.title = page.title if page.title
      self.description = page.best_description if page.best_description
      self.thumbnail = page.images.best if page.images.best
    rescue
      return false
    end

    false
  end

  def thumbnail_url
    external_resource self.thumbnail
  end

  def icon_url
    external_resource self.icon
  end

  def homepage_url
    nil unless self.homepage.present?
    self.homepage if self.homepage.include?('http://') or self.homepage.include?('https://')
    "http://#{self.homepage}"
  end

  def repository=(val)
    self[:repository] = val.sub('https://', '').sub('github.com/', '')
  end

  def repository_url
    "https://github.com/#{self.repository}"
  end

  def display_title
    return self.title if self.title.present?
    return self.homepage if self.homepage.present?
    return self.repository if self.repository.present?

    'My Project'
  end

  private

  def client
    @client ||= Octokit::Client.new(:access_token => self.user.github_token)
  end

  def external_resource(href)
    return nil unless href.present?
    return href if href.include?('http://') or href.include?('https://')

    pure_homepage = self.homepage.sub(/^https?\:\/\//, '').sub(/^www./, '')
    href = "#{pure_homepage}/#{href}" if self.homepage.present? and !href.include?(pure_homepage)

    protocol = self.homepage.include?('https://') ? 'https' : 'http'
    "#{protocol}://#{href}"
  end
end
