require 'nokogiri'
require 'open-uri'
require 'yaml'
require 'date'
require 'tmpdir'
require 'archive/zip'
require 'fileutils'

class HUDUpdater
  GROUP_URL = 'http://steamcommunity.com/groups/frankenhud/rss'
  DL_PATH = 'hud.zip'

  attr_reader :extras
  attr_accessor :cfg

  def initialize
    # temporary directory for extracting the archive
    @temp = Dir.mktmpdir
    ObjectSpace.define_finalizer self, proc { FileUtils.remove_entry_secure @temp }

    # configuration file
    if File.exist? 'config.yml'
      @cfg = YAML.load_file 'config.yml'
    else
      @cfg = { extras: [] }
    end
  end

  def look_for_update(force = true, last_id = @cfg[:version])
    # don't check automatically twice a day
    unless force
      if File.exist?(DL_PATH) && @cfg[:last_update] == Date.today
        puts 'Already checked today, using old data'
        analyze_update DL_PATH
        return true
      end
    end
    @cfg[:last_update] = Date.today

    puts 'Looking for an update...'

    doc = Nokogiri::XML(open(GROUP_URL))
    doc.css('item').each do |item|
      title = item.at_css('title').content
      m = /Release (\d+)/.match title
      if m
        version = m[1]
        desc = item.at_css('description').content
        url = /http:\/\/.+\.zip/.match(desc)
        next unless url
        if !File.exist?(DL_PATH) || last_id.to_s != version
          puts 'Downloading new file'
          load_update url[0]
          @cfg[:version] = version
          @cfg[:title] = title
          @cfg[:desc] = desc.gsub(url[0], '').strip
          save_config
          return true
        end
        break
      end
    end
    save_config
    if File.exist? DL_PATH
      puts 'Using previously downloaded file'
      analyze_update DL_PATH
      return true
    end
    false
  end

  def load_update(url)
    path = DL_PATH
    open url do |file|
      if file.content_type != 'application/zip'
        puts 'Update file invalid.'
        return
      end
      File.open path, 'wb' do |f|
        f.write file.gets nil
      end
    end
    puts 'Download complete'
    analyze_update path
  end

  def analyze_update(path)
    puts 'Extracting...'
    extract path, @temp
    @hud = File.join @temp, 'HUD'
    extract File.join(@temp, 'Extras.zip'), @temp
    @extras = {}
    extras_path = File.join(@temp, 'Extras')
    Dir.foreach(extras_path) do |entry|
      next if entry == '..' || entry == '.'
      @extras[entry] = File.join extras_path, entry
    end
    @update_available = true
  end

  def apply_update(dest, extras = @cfg[:extras])
    return false unless @update_available
    copy = [@hud]
    extras.each do |name|
      copy << @extras[name] if @extras.has_key? name
    end
    copy.each do |path|
      Dir.foreach(path) do |entry|
        next unless entry != '.' && entry != '..'
        entry = File.join(path, entry)
        if File.directory?(entry)
          FileUtils.cp_r entry, dest, remove_destination: true
        end
      end
    end
  end

  def save_config
    File.open 'config.yml', 'w' do |f|
      f.write @cfg.to_yaml
    end
  end

private
  def extract(path, dir)
    Archive::Zip.open path do |zip|
      zip.extract dir
    end
  end
end

