require './frankenhud.rb'
require 'green_shoes'
require 'win32/registry'

class Shoes
  class App
    def icon filename=nil
      filename.nil? ? win.icon : win.icon = filename
    end
  end
end

Shoes.app title: 'FrankenHUD Updater' do
  icon 'game.ico'
  @updater = HUDUpdater.new
  def check_update(force)
    if @updater.look_for_update force
      @content.clear
      @content.append do
        @updater.extras.each_key do |opt|
          flow do
            ch = check
            ch.checked = @updater.cfg[:extras].include? opt
            ch.click do |c|
              if c.checked?
                @updater.cfg[:extras] << opt
              else
                @updater.cfg[:extras].delete opt
              end
              @updater.save_config
            end
            para opt, width: 500, stroke: gray(54 / 255)
          end
        end
        button 'Apply' do
          dest = @users[@updater.cfg[:user]]
          if dest && File.directory?(dest)
            @updater.apply_update dest
          else
            alert 'No valid user selected!'
          end
        end
      end
    end
  end

  def valid_users
    steam_path = nil
    path = 'SOFTWARE\Valve\Steam'
    begin
      Win32::Registry::HKEY_LOCAL_MACHINE.open(path) do |reg|
        steam_path = reg['InstallPath']
      end
    rescue Win32::Registry::Error
    end
    steam_path = @updater.cfg[:steam_path] unless steam_path
    while steam_path.nil?
      alert 'Steam install path could not be found automatically, please select manually!'
      steam_path = ask_save_folder
    end
    @updater.cfg[:steam_path] = steam_path
    users = {}
    steamapps = File.join steam_path, 'steamapps'
    Dir.foreach(steamapps) do |dir|
      next if dir == '.' || dir == '..' || dir == 'common'
      tf = File.join steamapps, dir, 'team fortress 2/tf'
      users[dir] = tf if File.directory? tf
    end
    @users = users
    users.keys
  end

  background rgb(210, 205, 200)
  stack margin: 10 do
    title 'FrankenHUD Updater', stroke: rgb(179, 82, 21), size: 28, weight: 'bold'
    button('Check for update') { check_update true }
    user_box = list_box items: valid_users
    user_box.choose @updater.cfg[:user] if @updater.cfg[:user]
    user_box.change do
      user = user_box.text
      @updater.cfg[:user] = user
      @updater.save_config
    end
    @content = stack do
      subtitle 'Please update.'
    end
  end
  check_update false
end