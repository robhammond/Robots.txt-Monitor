# Robots Monitor
Monitor changes to robots.txt files

## Getting started

### Prerequisites

* Perl 5.10+
* MongoDB 3+
* Git

### Installing

Make a copy of robots_monitor.conf.sample to robots_monitor.conf:

```
cp robots_monitor.conf.sample robots_monitor.conf
```

Customise the config file as appropriate.

Ensure you have set your git global email & user name:

```
git config --global user.email "test@example.com"
git config --global user.name "Test"
```

Install the necessary Perl modules using [cpanm](https://metacpan.org/pod/App::cpanminus):

```
cpanm Mojolicious MongoDB
```

Run the server using:

```
# Development
morbo script/robots_monitor
# Production
hypnotoad script/robots_monitor
```

## Built With

* [Mojolicious](http://mojolicious.org/) - Next generation web framework for Perl

## Authors

* **[Rob Hammond](https://github.com/robhammond)**

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details