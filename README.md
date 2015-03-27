README
===

Autobot is a simple [XMPP](http://xmpp.org/) bot written in Perl and [AnyEvent](http://software.schmorp.de/pkg/AnyEvent.html).

The bot responds to messages as commands. The first word of each message is interpreted as a command name. The application looks for an executable file with the respective name in its command directory and runs it passing the remaining words as arguments.

The environment variables `FROM` and `TO` are set with the respective JIDs and the program output is sent back as the command reply.

The bot also has an HTTP service that allows external applications to send messages and retrieve information about the connection status.

Usage
---

    Usage:
        autobot [OPTIONS]
    Options:
        -j, --jid <jid>
        -p, --password <password>
        -c, --config <file>

Configuration file
---

The application search for a configuration file in the following order:

1. The file specified via the `--config` argument.

2. `~/autobot.conf`

3. `./autobot.conf`

4. `/etc/autobot.conf`

Comments start with `#` and every configuration follows the format:

    key = value

The recognized configurations are:

- `jid`: the Jabber ID (this config overrides the `--jid` argument).

- `password`: the password for the Jabber ID (this config overrides the `--password` argument);

- `bind_address`: the bind address for the HTTP service (default: `127.0.0.1`).

- `bind_port`: the bind port for the HTTP service (default: `8001`).

- `cmd_dir`: the directory where the executables commands are located at (default: `./cmd/`).

- `reconnect_time`: amount of time in seconds between reconnection tries (default: `3`). A negative value means no reconnection.

Example:

    # Mandatory configuration:
    jid = your.user@xmpp.server.com
    password = yourpassword

    # Default values:
    #bind_address = 127.0.0.1
    #bind_port = 8001
    #cmd_dir = ./cmd/
    #reconnect_time = 3

HTTP service
---

The bot responds to the following requests:

- `GET /is_connected`

    Return: `0` or `1`.

- `POST /send_to/$jid`

    Send a message to `$jid`.

- `POST /broadcast`

    Send a message to all contacts in its roster.

Dependencies
---

- AnyEvent
- AnyEvent::Log
- AnyEvent::XMPP
- Config::General
- Twiggy::Server
- Dancer
- EV

Todos
---

- Support for OTR (Off The Record).
- Local communication using unix sockets.
- File logging (currently it logs to stderr).
- Makefile install.

Local install
---

The following steps can be used to install `autobot` as a service in Arch Linux. However, they will probably work in any other distro that uses systemd.

1. Make sure that `perl`, `gcc`, `cpan` and `local::lib` are installed in the system.

2. Create the destination directory:

        mkdir /opt/autobot

3. Create an user for autobot:

        useradd -d /opt/autobot -s /bin/nologin -U autobot

4. Copy files to the destination directory:

        tar xvf ./autobot.tar.gz -C /opt/autobot

5. Change ownership:

        chown -R autobot:autobot /opt/autobot

6. Start a shell as the new user:

        su - autobot -s /bin/sh

7. Create local library directory:

        cd /opt/autobot
        mkdir perl

8. Set the environment to point to the local library directory:

        perl -Mlocal::lib=./perl/ # Check the variables values
        eval $(perl -Mlocal::lib=./perl/)

9. Install perl dependencies from CPAN:

        cpan install AnyEvent
        cpan install AnyEvent::Log
        cpan install AnyEvent::XMPP
        cpan install Config::General
        cpan install Twiggy::Server
        cpan install Dancer
        cpan install EV

10. Configure the file autobot.conf as the following:

        # Mandatory configuration:
        jid = your.user@xmpp.server.com
        password = yourpassword

        # Default values:
        #bind_address = 127.0.0.1
        #bind_port = 8001
        #cmd_dir = ./cmd/
        #reconnect_time = 3

11. Change autobot.conf permissions

        chmod 600 autobot.conf

12. Logout

        exit

13. Create a systemd service file in /etc/systemd/system/autobot.service:

        [Unit]
        Description=AutoBot
        After=network.target

        [Service]
        User=autobot
        Group=autobot
        Type=simple
        WorkingDirectory=/opt/autobot/
        ExecStart=/usr/bin/perl -Mlocal::lib=/opt/autobot/perl/ /opt/autobot/autobot
        Restart=on-failure
        RestartSec=10

        [Install]
        WantedBy=multi-user.target

14. Enable service:

        systemctl daemon-reload
        systemctl enable autobot.service
        systemctl start autobot.service

15. Check the service:

        journalctl -u autobot.service -e

