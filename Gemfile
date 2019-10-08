# frozen_string_literal: true

source 'http://rubygems.org'

gem 'stove'

group :development do
  gem 'knife-cookbook-doc', '>=0.13.0'
  gem 'berkshelf'
end
group :integration do
  gem 'kitchen-inspec'
  gem 'test-kitchen'
end

group :vagrant do
  gem 'kitchen-vagrant'
  gem 'vagrant-wrapper'
end

group :docker do
  gem 'kitchen-docker'
end

group :dokken do
  gem 'kitchen-dokken'
end
