# Rosa

This is a queue monitoring and assignment tool used in production internally by the SUSE Linux team.

## Getting Started

These instructions will get internal SUSE employees a copy of the project up and running on a local SLES 12 SP1 machine for development and testing purposes. I imagine future service packs on the same major version will basically stay the same. 

### Prerequisites

Make sure you are fully patched on a SLES 12 SP1. You will also need the SLE-Module-Web-Scripting12-Updates and SLE-SDK12-SP1-Pool add-on repositories. Lastly, you will need a custom repository for node.js. Ill get into the specifics of that in the installation process.

Access to internal tools will be a necessity: siebel, proetus, qmon

```
rosa@rni:~> zypper ls
# | Alias                                                        | Name                                                         | Enabled | GPG Check | Refresh | Type  
--+--------------------------------------------------------------+--------------------------------------------------------------+---------+-----------+---------+-------
1 | SUSE_Linux_Enterprise_Server_12_SP1_x86_64                   | SUSE_Linux_Enterprise_Server_12_SP1_x86_64                   | Yes     | ----      | Yes     | ris   
2 | SUSE_Linux_Enterprise_Software_Development_Kit_12_SP1_x86_64 | SUSE_Linux_Enterprise_Software_Development_Kit_12_SP1_x86_64 | Yes     | ----      | Yes     | ris   
3 | Web_and_Scripting_Module_12_x86_64                           | Web_and_Scripting_Module_12_x86_64                           | Yes     | ----      | Yes     | ris   
4 | NodeJS                                                       | NodeJS                                                       | Yes     | (r ) Yes  | No      | rpm-md
```

### Installing

Start by installing the following packages.

```
sudo zypper install ruby-devel ruby2.1-rubygem-rails-4_2 ruby2.1-rubygem-bundler gcc make zlib zlib-devel sqlite3 sqlite3-devel
```

Next install rails through gem.

```
sudo gem install rails
```

Then run through a bundle install.

```
bundle install
```

From there you should be able to run a rails command.

```
rosa@rni:~> rails -v
Rails 4.2.4
```
Next add this custom repo so that you can install nodejs. If you arent using SLES 12 SP1 youll need to find an equivalant that will work for your environment.

```
rosa@rni:~> cat /etc/zypp/repos.d/NodeJS.repo 
[NodeJS]
enabled=1
autorefresh=0
baseurl=http://download.opensuse.org/repositories/OBS:/Server:/2.7/SLE_12/
type=rpm-md
```

```
sudo zypper install nodejs
```

Next use the following documentation to setup Nginx with Phusion passenger.

[Nginx/PhusionPassenger](https://wiki.archlinux.org/index.php/Ruby_on_Rails#Apache.2FNginx_.28using_Phusion_Passenger.29)

Heres the configuration in the nginx.conf as we set it up since the root was in /srv/www/htdocs/rosa.

```
server {
        listen		80;
        server_name	rosa.lab.novell.com;
        root		/srv/www/htdocs/rosa/public;
        passenger_enabled on;
        rails_env	production;
    }
```

After setting that up youll need to put together a systemd service file for it. The following is how it was setup in my case since I installed nginx into /opt.

```
[Unit]
Description=nginx - high performance web server
Documentation=http://nginx.org/en/docs/
After=network.target remote-fs.target nss-lookup.target
 
[Service]
Type=forking
ExecStartPre=/opt/nginx/sbin/nginx -t -c /opt/nginx/conf/nginx.conf
ExecStart=/opt/nginx/sbin/nginx -c /opt/nginx/conf/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
 
[Install]
WantedBy=multi-user.target
```

Make sure that when you extracted the Rosa files that they are owned by the user youve configured nginx to use so that it can access properly.

For Ruby on Rails in production you want to have the secret used for verifying signed cookies set in a different location than the file itself. You'll see in the config/secrets.yml that it points to an environment variable. You can place it into the bash environment variable:

```
# Ruby Production Environment Secret
export SECRET_KEY_BASE=<key>
export RAILS_ENV=production
```

Next, youll need access to the internal qmon tool and make sure that it is installed properly on the box and enabled. The following command should bring back results.

```
qmon -qv <queue name>
```

Next, make sure to setup a logrotate file:

```
rosa@rni:~> cat /etc/logrotate.d/rails_rosa 
/srv/www/htdocs/rosa/log/*.log {
  size 100M
  missingok
  rotate 3
  compress
  compresscmd /usr/bin/bzip2
  compressext .bz2
  delaycompress
  notifempty
  copytruncate
}
```

* Note: You'll want to make a logrotate file for the nginx log as well.

Almost done! Crons will have to be setup to run as the user who owns the rosa files.

```
rosa@rni:~> crontab -l
# DO NOT EDIT THIS FILE - edit the master and reinstall.
# (/tmp/crontab.G6A6WH installed on Wed Sep 14 07:40:32 2016)
# (Cronie version 4.2)
*/7 * * * * /bin/bash -l -c 'cd /srv/www/htdocs/rosa && bundle exec rake refresh_data --silent >/dev/null 2>&1'
*/30 * * * * /bin/bash -l -c '/srv/www/htdocs/rosa/app/assets/scripts/refresh_queue.sh >/dev/null 2>&1'
*/5 * * * * /bin/bash -l -c 'cd /srv/www/htdocs/rosa && bundle exec rake refresh_srs --silent >/dev/null 2>&1'
58 23 * * * /bin/bash -l -c 'cd /srv/www/htdocs/rosa && bundle exec rake refresh_taken --silent >/dev/null 2>&1'
```
* The first cron pulls the stats data using a rake task.
* The second cron runs a bash script that then runs a rake task every 8 seconds. It uses a lock file to prevent multiple instances of the script from running.
* The third cron refreshes important information on the SRs in the database that might have been changed in siebel directly since the creation of the SR in the Maria database.
* The fourth cron clears the SRs Taken table once a night at 11:58 pm.

Going into production the assets pipeline has to be precompiled before starting anything. Stop nginx if you have it running. This will be necessary any time you make an asset change. e.g. css, javascript, images, etc.

```
sudo systemctl stop nginx
spring stop
rake assets:precompile
```

Next is the part I can describe the least since it involves the specific urls used internally to access the needed data to make Rosa tick properly. the config/confidential.json file has all the needed data. The following is how I have it setup with the urls removed. If you are an internal employee you should be able to get access to Rosa and this file so that you can see what urls are used in order to setup your own instance:

```
{
  "sr_info": "",
  "username": "",
  "password": "",
  "returning_info": "",
  "ltss_info": "",
  "assign_info": "",
  "oncall_doc": "",
  "siebelmatic_db": "",
  "sla_doc": "",
  "open_srs": "",
  "closed_srs": "",
  "workforce_id": "",
  "survey_scores": "",
  "wallboard": ""
}

```

Setup of the overall system is now complete. Next is just setting up desired queues and users. Youll need to adjust the ourqueues.txt, otherqueues.txt, and usernames.txt to have the users you want to be listed and able to assign, the our queues you want to monitor, and the other queues you want to be able to move cases to. In each of those files it will indicate what rake task to run in order to build based on the file configuration. You should now be able to start nginx and access the web page from the domain you setup.

```
systemctl start nginx
```

## Additional Notes

You can add a note to the teaminfo.txt file at any time and it will display above the SRs in queue section of the web page. No restart of nginx is necessary. When it is done make sure to 0 out the file so that it is empty again and the message will go away.

```
truncate --size=0 teaminfo.txt
```

## Built With

* [Ruby](https://www.ruby-lang.org/en/) - The primary programming language
* [Rails](http://rubyonrails.org/) - The web framework utilizing Ruby
* [Nginx](https://www.nginx.com/) - The web service used to present the website
* [PhusionPassenger](https://www.phusionpassenger.com/) - Web app used to integrate rails with nginx
* [Javascript](https://www.javascript.com/) - Used to refresh the webpage automatically in intervals

## Contributing

Please read [CONTRIBUTING.md](https://github.com/ZeTopHat/Rosa/blob/master/CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Author

* **Colin Hamilton** - *Initial work* - [ZeTopHat](https://github.com/ZeTopHat)
* **Erick Diaz** - *Refactoring Guru* - [Bearlock](https://github.com/Bearlock)

See also the list of [contributors](https://github.com/ZeTopHat/Rosa/contributors) who participated in this project.

## Acknowledgments

* Hat tip to my good friend Erick Diaz for always pushing me to improve my code
* To that God-awful tool Igor that drove me to create something better

