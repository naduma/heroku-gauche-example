# Gauche on Heroku: Example app

This app is an example of [Heroku buildpack: Gauche][heroku-buildpack-gauche].

    $ git clone https://github.com/naduma/heroku-gauche-example.git
    $ cd ./heroku-gauche-example
    $ heroku create --buildpack https://github.com/naduma/heroku-buildpack-gauche.git
    $ heroku addons:add heroku-postgresql --app [app name]
    $ heroku pg:psql --app [app name]
    table.sql
    > create table bbs (name varchar(32), message text, added timestamp default current_timestamp);
    $ git push heroku master

[heroku-buildpack-gauche]: https://github.com/naduma/heroku-buildpack-gauche
