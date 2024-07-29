# Elden Ring SeamlessCoop Backup Manager for Steam Deck

A bash utility for managing backups of Elden Ring SeamlessCoop saves.

## Motivation

Managing SeamlessCoop versions on Steam Deck has a few challenges, such as
needing to backup and transfer your saves after each upgrade.  Backups keep
your saves safe in the event of an upgrade failure, while transfers are
required to play old saves on new versions of SeamlessCoop (a new `compatdata`
directory is created for each version of SeamlessCoop added to your Steam
library).

I got tired of `ssh`ing into my deck to manage backups.  I even had a few
failed upgrades resulting in save file loss.  It's possible for files/data to be
removed by Steam as part of official Deck updates, creating the need for
backups to be stored off the deck as well.

## Requirements

This guide assumes you have basic terminal knowledge.  Additionally, you will
need:

* [gum](https://github.com/charmbracelet/gum)
* [direnv](https://direnv.net/)
* [an ssh-enabled steam deck](https://github.com/gamagoat/setting-up-ssh-on-steam-deck)

This script written and tested using bash on macOS.

## Usage

### Environment setup

Create a copy of `.envrc.sample` that you export using `direnv`:

```sh
cp .envrc.sample .envrc
```

Modify the .envrc based on the directions therein.  Once done, lets make the
environment variables available to our script:

```sh
direnv allow .
```

> [!NOTE]
> Anytime you change your .envrc, you will need to run `direnv allow .` again.

### Finding your compatdata dir

## TODO

* [x] Create new backups
* [x] Synchronize backups to a local machine
* [x] List all relevant compatdata dirs
* [ ] Transfer backups from one version of SeamlessCoop to another
* [ ] Generalize script to work with any game on Steam Deck
