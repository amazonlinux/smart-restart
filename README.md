# Smart-Restart

This package restarts systemd services on system updates every time a package is updated (installed or 
deleted) using the systems package mamanger (every time `dnf {update, upgrade, downgrade}` is executed).
It primarily is tailored for Amazon Linux 2023 but easily can be ported to all RPM based systems like 
Fedora. Smart-Restart utilizes the `needs-restarting` package from `dnf-utils` and a custom denylisting 
mechanism to determine which services need to be restarted and how to determine if a system reboot is 
advices. In case a system reboot is advised, a reboot hint marker file is generated 
(`/run/smart-restart/reboot-hint-marker`) containing the services and other components which require a 
restart.

# Install using the package manager on AL2023

```
sudo dnf install -y smart-restart 
```

On the next `sudo dnf update/downgrade/install/erase` invocation, this script will kick in and restart all 
services which are not denylisted if necessary.

# Configuration

## Denylisting

Smart-Restart can be instructed to block certain services from being restarted. Those services also won't 
contribute to the decision if a reboot is required.
To add new services, put a file with the suffix `-denylist` in `/etc/smart-restart-conf.d/`. Lines starting 
with "#" will be ignored.

```
cat /etc/smart-restart-conf.d/custom-denylist
# Some comments
myservice.service
```

All `*-denylist` files are read and evaluated when making the decision.

## Custom hooks

Additionally to denylisting, Smart-Restart provides a mechanism to run custom scripts before and after the 
service restart attempts. Those can be used to manually perform preparation steps or inform other components
of a outstanding or completed restart.

All scripts in `/etc/smart-restart-conf.d/` with the suffix `-{pre,post}-restart` are executed. In case the order
is important, prefix all scripts with a number to ensure the execution order. For example

```
ls /etc/smart-restart-conf.d/*-pre-restart

001-my-script-pre-restart
002-some-other-script-pre-restart
```

# Manual installation

For now, manual installation of Smart-Restart supports AL2 and AL2023. The main reason for the differentiation 
is the package manager. AL2 mainly uses `yum` and AL2023 `dnf`. The following prequsites bring the `needs-restarting`
script and the a package managers plugin which allows to hook into the different parts of the package managers
installation process. 


## Installation

For dnf based systems:
```
sudo dnf install -y dnf-utils dnf-plugin-post-transaction-actions
sudo make install
```

For yum based systems:
```
sudo yum install -y yum-utils yum-plugin-post-transaction-actions
sudo make install
```

In case this package is installed on RPM based systems which are not Amazon Linux, the installation will fail 
recognizing the distribution. This behavior can be overriden forcing `make` to assume `yum or dnf` as main 
package manager using `DIST_OVERRIDE=.amzn2` or `DIST_OVERRIDE=.amzn2023` respectively.

Example:
```
sudo make DIST_OVERRIDE=.amzn2 install
```

# Contribution

For instructions on how to contribute to this project consult the [CONTRIBUTION](CONTRIBUTION.md) document.

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This project is licensed under the Apache-2.0 License.

