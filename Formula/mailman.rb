require 'formula'

class Mailman < Formula
  homepage 'https://www.gnu.org/software/mailman/'
  url      'https://ftpmirror.gnu.org/mailman/mailman-2.1.15.tgz'
  sha256   'f355fb3d31772b488449e6f5173dafd31edca93172c307244c791d25d9e2bec8'

  ##
  # varprefix is where we're going to put all the mailman data. It
  # won't be removed between uninstalls to make upgrades easier.

  def varprefix
    HOMEBREW_PREFIX/'share/mailman'
  end

  def install
    ENV.deparallelize # parallel builds break

    puts "NOTE: mailman _must_ be installed by root. Using sudo below:"

    [prefix, varprefix].each do |path|
      mkdir_p path
      system "sudo", "chgrp", "_mailman", path
      system "sudo", "chmod", "a+rx,g+ws", path
    end

    system "./configure", "--prefix=#{prefix}", "--with-var-prefix=#{varprefix}"

    system "make", "install"
    system "sudo", "chmod", "o-x", "#{varprefix}/archives/private"
    Dir.chdir prefix do
      system "sudo", "./bin/check_perms", "-f"
    end

    apache_conf_path.write apache_conf
    apache_conf_path.chmod 0644

    test # no really... make sure the perms are set right.
  end

  def apache_conf_path
    prefix+"httpd-mailman.conf"
  end

  def apache_conf
    <<-"EOS".undent
      ScriptAlias /mailman/ "#{prefix}/cgi-bin/"
      Alias /pipermail/     "#{varprefix}/archives/public/"
      Alias /icons/         "#{prefix}/icons/"
      <Directory "#{varprefix}/archives/public/">
          Options FollowSymLinks MultiViews Indexes
          AllowOverride None
          Order allow,deny
          Allow from all
      </Directory>
    EOS
  end

  def startup_plist
    <<-EOS.undent
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>Debug</key>
          <true/>
          <key>Disabled</key>
          <false/>
          <key>Label</key>
          <string>org.list.mailmanctl</string>
          <key>Program</key>
          <string>#{HOMEBREW_PREFIX}/bin/mailmanctl</string>
          <key>ProgramArguments</key>
          <array>
              <string>mailmanctl</string>
              <string>-s</string>
              <string>start</string>
          </array>
          <key>KeepAlive</key>
          <false/>
          <key>RunAtLoad</key>
          <true/>
          <key>AbandonProcessGroup</key>
          <true/>
      </dict>
      </plist>
    EOS
  end

  def caveats
    <<-"EOS".undent
      DONE! But that's the easy part!

      Code is in #{prefix}.
      Data is in #{varprefix}.

      To start (or upgrade) as a service:

        sudo launchctl unload -w /Library/LaunchDaemons/#{plist_path.basename}
        sudo cp #{plist_path} /Library/LaunchDaemons/
        sudo launchctl load -w /Library/LaunchDaemons/#{plist_path.basename}

      To add to apache:

        cp #{apache_conf_path} /etc/apache2/extra

      Add to httpd.conf:

        Include /etc/apache2/extra/httpd-mailman.conf

      When in doubt, double-check against these instructions:

        http://www.livetime.com/mountain-lion-mailman-mailing-list/

      Done! Enjoy!

    EOS
  end

  test do
    system "#{bin}/check_perms"
  end
end
