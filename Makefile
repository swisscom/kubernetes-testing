.PHONY: all test bundler install package fast before after rspec

all: install test
test: before rspec after

rspec:
	bundle exec rspec
before:
	bundle exec ruby before_suite.rb
after:
	bundle exec ruby after_suite.rb

fast:
	bundle exec rspec -t fast

bundler: install package
install:
	bundle config set --local path 'vendor'
	bundle install
package:
	bundle package
